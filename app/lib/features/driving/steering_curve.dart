import 'dart:math' as math;

/// "Centre precision" of the steering, like the linearity of a wheel in the
/// game: 0 keeps the steering linear, higher values make small moves around
/// the centre finer while full lock stays at the same place. Pure,
/// unit-tested.
class SteeringCurve {
  SteeringCurve._();

  /// Exponent at full precision (1): half tilt gives about 18 % of lock.
  static const double maxExponent = 2.5;

  /// [steering]: 0 (full right) .. 0.5 (centre) .. 1 (full left);
  /// [precision]: 0..1.
  static double apply(double steering, double precision) {
    if (precision <= 0) return steering;
    final offset = ((steering - 0.5) * 2).clamp(-1.0, 1.0);
    final exponent = 1 + (maxExponent - 1) * precision.clamp(0.0, 1.0);
    final shaped = offset.sign * math.pow(offset.abs(), exponent);
    return 0.5 + shaped / 2;
  }
}
