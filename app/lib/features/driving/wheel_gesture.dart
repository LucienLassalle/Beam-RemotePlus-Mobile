/// Turning a wheel drawn on the screen with one finger: the angle follows the
/// finger around the wheel centre, up to [maxAngleDeg] each way. Pure,
/// unit-tested; the widget is widgets/touch_wheel.dart.
class WheelGesture {
  /// Wheel rotation giving full lock, each way.
  double maxAngleDeg;

  /// Current wheel rotation, clockwise positive (turning right).
  double angleDeg = 0;
  double? _lastFingerDeg;

  WheelGesture({required this.maxAngleDeg});

  /// Steering value of the protocol: 0 (full right) .. 0.5 .. 1 (full left).
  double get steering => (0.5 - angleDeg / (2 * maxAngleDeg)).clamp(0.0, 1.0);

  /// Finger put down at [fingerDeg] (screen angle around the centre,
  /// clockwise as the y axis points down): the wheel does not jump.
  void start(double fingerDeg) => _lastFingerDeg = fingerDeg;

  /// The finger moved: the wheel turns by the same angle (through the ±180°
  /// seam too), stopping at full lock.
  void move(double fingerDeg) {
    final last = _lastFingerDeg;
    _lastFingerDeg = fingerDeg;
    if (last == null) return;
    var delta = fingerDeg - last;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    angleDeg = (angleDeg + delta).clamp(-maxAngleDeg, maxAngleDeg);
  }

  void end() => _lastFingerDeg = null;
}
