import 'dart:math' as math;

/// Turns accelerometer samples into a steering value (0 = full right,
/// 0.5 = centre, 1 = full left) and pitch gestures. Pure logic, unit-tested.
///
/// - Calibration: the first [calibrationSamples] samples define the resting
///   position; roll and pitch are measured relative to it, which cancels
///   sensor bias and the natural holding angle.
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
  /// rotation range: 360° -> 75°, 900° -> 187.5° (capped by the clamp).
  static double maxTiltDegFor(double rotationRangeDeg) => rotationRangeDeg * (75.0 / 360.0);

  double rotationRangeDeg;
  bool invert;
  bool smoothing;

  int _count = 0;
  double _sumX = 0, _sumY = 0, _sumZ = 0;
  double _restX = 0, _restY = 0, _restMag = 9.81;
  bool _calibrated = false;
  double? _smoothedRoll;

  TiltSteering({this.rotationRangeDeg = 900, this.invert = false, this.smoothing = true});

  bool get calibrated => _calibrated;

  void recalibrate() {
    _count = 0;
    _sumX = _sumY = _sumZ = 0;
    _calibrated = false;
    _smoothedRoll = null;
  }

  static double _deg(double ratio) => math.asin(ratio.clamp(-1.0, 1.0)) * 180 / math.pi;

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
        _calibrated = true;
      }
      return 0.5;
    }

    var roll = _deg(y / mag) - _deg(_restY / _restMag);
    final deviation = (mag - _restMag).abs();
    final confidence = deviation <= shakeSoftDeviation
        ? 1.0
        : deviation >= shakeHardDeviation
            ? shakeMinConfidence
            : 1.0 - (deviation - shakeSoftDeviation) / (shakeHardDeviation - shakeSoftDeviation) * (1.0 - shakeMinConfidence);
    final alpha = (smoothing ? emaAlpha : 1.0) * confidence;
    _smoothedRoll = _smoothedRoll == null ? roll : _smoothedRoll! + alpha * (roll - _smoothedRoll!);
    roll = _smoothedRoll!;
    if (roll.abs() < centerDeadZoneDeg) roll = 0;

    final sign = invert ? 1.0 : -1.0;
    final value = (sign * roll / maxTiltDegFor(rotationRangeDeg) / 2).clamp(-0.5, 0.5) + 0.5;
    return value.clamp(0.0, 1.0);
  }

  /// Pitch (degrees) relative to the resting position: negative = tilted
  /// forward. 0 before calibration.
  double pitch(double x, double y, double z) {
    if (!_calibrated) return 0;
    final mag = math.sqrt(x * x + y * y + z * z);
    if (mag < 0.5) return 0;
    return _deg(x / mag) - _deg(_restX / _restMag);
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
