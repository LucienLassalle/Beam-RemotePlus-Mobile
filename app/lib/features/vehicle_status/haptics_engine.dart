import '../../core/protocol/telemetry.dart';

/// One vibration: duration and strength (1..255, Android amplitude).
class Pulse {
  final int durationMs;
  final int amplitude;
  const Pulse(this.durationMs, this.amplitude);

  @override
  String toString() => 'Pulse($durationMs ms, $amplitude)';
}

/// Turns telemetry into "road feel" vibrations. Pure, unit-tested:
/// - impact: sudden change of acceleration (crash, landing, kerb strike)
/// - slip: wheelspin, locked wheels or drifting, stronger with the slip
/// - rumble: vertical shocks (kerbs, rough road)
/// At most one pulse every [minGap] so the phone never buzzes constantly.
class HapticsEngine {
  static const double impactThreshold = 25; // m/s² change between frames
  static const double slipThreshold = 2; // m/s
  static const double rumbleThreshold = 4; // m/s² away from gravity
  static const Duration minGap = Duration(milliseconds: 90);

  /// 0.0 .. 1.0, user strength setting.
  double strength;

  HapticsEngine({this.strength = 1});

  double? _gx, _gy, _gz;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  Pulse? update(Telemetry t, DateTime now) {
    final pulse = _compute(t);
    _gx = t.gx;
    _gy = t.gy;
    _gz = t.gz;
    if (pulse == null || strength <= 0) return null;
    // Impacts always go through, the rest respects the gap.
    if (pulse.durationMs < 100 && now.difference(_last) < minGap) return null;
    _last = now;
    return Pulse(pulse.durationMs, (pulse.amplitude * strength).round().clamp(1, 255));
  }

  Pulse? _compute(Telemetry t) {
    final gx = t.gx, gy = t.gy, gz = t.gz;
    if (gx != null && gy != null && gz != null && _gx != null && _gy != null && _gz != null) {
      final dx = gx - _gx!, dy = gy - _gy!, dz = gz - _gz!;
      final jolt = dx * dx + dy * dy + dz * dz;
      if (jolt > impactThreshold * impactThreshold) return const Pulse(140, 255);
    }
    final slip = t.wheelSlip ?? 0;
    if (slip > slipThreshold) {
      final intensity = ((slip - slipThreshold) / 12).clamp(0.0, 1.0);
      return Pulse(25, (60 + intensity * 160).round());
    }
    if (gz != null && ((gz.abs() - 9.81).abs() > rumbleThreshold)) return const Pulse(18, 70);
    return null;
  }
}
