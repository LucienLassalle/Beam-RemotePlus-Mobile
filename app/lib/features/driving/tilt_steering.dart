import 'dart:math' as math;

/// Turns accelerometer samples into a steering value (0 = full right,
/// 0.5 = centre, 1 = full left) and pitch gestures. Pure logic, unit-tested.
///
/// - Calibration: the first [calibrationSamples] samples define the resting
///   position; roll and pitch are measured relative to it, which cancels
///   sensor bias and the natural holding angle.
/// - Full rotation: the roll is the angle of gravity around the steering
///   axis (atan2, not asin, which folds back after 90°), followed from one
///   sample to the next across ±180°, so the phone can turn like a real
///   wheel, beyond a half turn each way.
/// - Smoothing: a light EMA removes sensor jitter; a small dead zone keeps
///   the centre steady.
/// - Shake rejection: under pure rotation the acceleration magnitude stays
///   ~g; a jolt of the hand (reflex during a spin) changes it, so such
///   samples are trusted less instead of producing a wild steering spike.
class TiltSteering {
  static const int calibrationSamples = 20;
  static const double emaAlpha = 0.35;
  static const double centerDeadZoneDeg = 0.6;
  static const double shakeSoftDeviation = 2.0; // m/s²
  static const double shakeHardDeviation = 6.0; // m/s²
  static const double shakeMinConfidence = 0.08;

  /// Phone tilt (degrees from rest) giving full lock for a virtual wheel
  /// rotation range: 360° -> 75°, 900° -> 187.5°.
  static double maxTiltDegFor(double rotationRangeDeg) => rotationRangeDeg * (75.0 / 360.0);

  /// Phone rotation (degrees from rest) giving full lock: [maxTiltDegFor],
  /// or half the range when the phone turns like a real wheel (900° range
  /// -> 450° each way).
  static double fullLockDegFor(double rotationRangeDeg, {bool realWheel = false}) =>
      realWheel ? rotationRangeDeg / 2 : maxTiltDegFor(rotationRangeDeg);

  /// Below this part of gravity around the steering axis (m/s²: phone held
  /// nearly along the axis) the roll is unreliable: it is kept as it was.
  static const double minPlanarGravity = 2.5;

  double rotationRangeDeg;
  bool invert;
  bool smoothing;

  /// Full lock at half the rotation range of phone rotation (1:1 with a
  /// real wheel), see [fullLockDegFor].
  bool realWheel;

  /// Samples come from the gyroscope fused with the accelerometer
  /// (GravitySensor) instead of the raw accelerometer. They have no
  /// jitter to filter: [smoothing] only applies to the accelerometer.
  bool fused;

  int _count = 0;
  double _sumX = 0, _sumY = 0, _sumZ = 0;
  double _restX = 0, _restY = 0, _restMag = 9.81;

  // Unit direction, in the phone's x/z plane, of gravity at rest: the
  // "down" the roll is measured from.
  double _downX = 0, _downZ = 1;

  // Last raw roll (-180..180) and the roll followed from it across turns.
  double _lastRaw = 0;
  double _roll = 0;
  bool _calibrated = false;
  double? _smoothedRoll;

  TiltSteering({
    this.rotationRangeDeg = 900,
    this.invert = false,
    this.smoothing = true,
    this.fused = false,
    this.realWheel = false,
  });

  bool get calibrated => _calibrated;

  void recalibrate() {
    _count = 0;
    _sumX = _sumY = _sumZ = 0;
    _calibrated = false;
    _smoothedRoll = null;
  }

  static double _deg(double ratio) => math.asin(ratio.clamp(-1.0, 1.0)) * 180 / math.pi;

  /// Angle (degrees, -180..180) of gravity around the steering axis: from
  /// the resting "down" towards the phone's y axis.
  double _rawRoll(double x, double y, double z) => math.atan2(y, x * _downX + z * _downZ) * 180 / math.pi;

  /// Adds the rotation since the last sample to the followed roll, through
  /// the ±180° seam; a sample held along the axis changes nothing.
  void _follow(double x, double y, double z) {
    final h = x * _downX + z * _downZ;
    if (math.sqrt(y * y + h * h) < minPlanarGravity) return;
    final raw = _rawRoll(x, y, z);
    var delta = raw - _lastRaw;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _lastRaw = raw;
    _roll += delta;
  }

  /// Steering value for this sample (0.5 while calibrating or for an
  /// unusable sample).
  double steering(double x, double y, double z) {
    final mag = math.sqrt(x * x + y * y + z * z);
    if (mag < 0.5) return 0.5; // free fall / bogus sample
    if (!_calibrated) {
      _sumX += x;
      _sumY += y;
      _sumZ += z;
      if (++_count >= calibrationSamples) {
        _restX = _sumX / _count;
        _restY = _sumY / _count;
        final rz = _sumZ / _count;
        _restMag = math.sqrt(_restX * _restX + _restY * _restY + rz * rz);
        if (_restMag < 0.5) _restMag = 9.81;
        final planar = math.sqrt(_restX * _restX + rz * rz);
        if (planar >= 0.5) {
          _downX = _restX / planar;
          _downZ = rz / planar;
        }
        _lastRaw = _rawRoll(_restX, _restY, rz);
        _roll = 0;
        _calibrated = true;
      }
      return 0.5;
    }

    _follow(x, y, z);
    var roll = _roll;
    final deviation = (mag - _restMag).abs();
    final confidence = deviation <= shakeSoftDeviation
        ? 1.0
        : deviation >= shakeHardDeviation
            ? shakeMinConfidence
            : 1.0 - (deviation - shakeSoftDeviation) / (shakeHardDeviation - shakeSoftDeviation) * (1.0 - shakeMinConfidence);
    final alpha = (smoothing && !fused ? emaAlpha : 1.0) * confidence;
    _smoothedRoll = _smoothedRoll == null ? roll : _smoothedRoll! + alpha * (roll - _smoothedRoll!);
    roll = _smoothedRoll!;
    if (roll.abs() < centerDeadZoneDeg) roll = 0;

    final sign = invert ? 1.0 : -1.0;
    final value = (sign * roll / fullLockDegFor(rotationRangeDeg, realWheel: realWheel) / 2).clamp(-0.5, 0.5) + 0.5;
    return value.clamp(0.0, 1.0);
  }

  /// Pitch (degrees) relative to the resting position: negative = tilted
  /// forward. Measured across the steering axis, so turning the phone, even
  /// far, never changes it. 0 before calibration.
  double pitch(double x, double y, double z) {
    if (!_calibrated) return 0;
    final mag = math.sqrt(x * x + y * y + z * z);
    if (mag < 0.5) return 0;
    return _deg((x * _downZ - z * _downX) / mag);
  }
}

/// Pitch gesture -> gear shift, with re-arming in the neutral zone and a
/// cooldown so one gesture never shifts twice.
class PitchShifter {
  final double thresholdDeg;
  final double neutralDeg;
  final Duration cooldown;
  bool _armed = true;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  PitchShifter({this.thresholdDeg = 25, this.neutralDeg = 20, this.cooldown = const Duration(milliseconds: 600)});

  /// Returns +1 (shift up), -1 (shift down) or 0.
  int update(double pitchDeg, DateTime now) {
    if (!_armed) {
      if (pitchDeg.abs() < neutralDeg) _armed = true;
      return 0;
    }
    if (now.difference(_last) < cooldown) return 0;
    final direction = pitchDeg < -thresholdDeg ? 1 : (pitchDeg > thresholdDeg ? -1 : 0);
    if (direction != 0) {
      _armed = false;
      _last = now;
    }
    return direction;
  }
}
