import 'dart:math' as math;

/// A car seen by the proximity radar, in the followed car's frame.
class RadarTarget {
  /// Metres to the right (negative = left).
  final double x;

  /// Metres ahead (negative = behind).
  final double y;

  /// Degrees relative to our heading (0 = same direction, 180 = oncoming).
  final double heading;
  final double length;
  final double width;

  const RadarTarget({required this.x, required this.y, this.heading = 0, this.length = 4.5, this.width = 1.9});

  double get distance => math.sqrt(x * x + y * y);

  static double _d(Object? v, double fallback) => v is num && v.isFinite ? v.toDouble() : fallback;

  factory RadarTarget.fromJson(Map<Object?, Object?> j) => RadarTarget(
        x: _d(j['x'], 0),
        y: _d(j['y'], 0),
        heading: _d(j['heading'], 0),
        length: _d(j['length'], 4.5),
        width: _d(j['width'], 1.9),
      );
}

/// Tyre data from the "Tyre Thermals and Wear" mod.
class TyreState {
  /// Average temperature (°C).
  final double? temp;

  /// Temperature where the tyre grips best (°C).
  final double? working;

  /// Remaining tread, 100 = new.
  final double? condition;
  final double? brake;

  const TyreState({this.temp, this.working, this.condition, this.brake});

  static double? _d(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

  factory TyreState.fromJson(Map<Object?, Object?> j) =>
      TyreState(temp: _d(j['temp']), working: _d(j['working']), condition: _d(j['condition']), brake: _d(j['brake']));

  /// -1 (cold) .. 0 (working temperature) .. 1 (overheating), null if unknown.
  double? get heat {
    if (temp == null || working == null || working! <= 0) return null;
    return ((temp! - working!) / (working! * 0.4)).clamp(-1.0, 1.0);
  }
}
