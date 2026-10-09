import '../../core/protocol/telemetry.dart';

/// One vibration: duration and strength (1..255, Android amplitude).
class Pulse {
  final int durationMs;
  final int amplitude;
  const Pulse(this.durationMs, this.amplitude);

  @override
  String toString() => 'Pulse($durationMs ms, $amplitude)';
}

/// Road-feel vibrations, each one can be switched off in the settings.
enum HapticKind {
  /// Wheelspin or sliding.
  spin,

  /// Locked wheels under braking.
  lock,

  /// Sudden change of acceleration: crash, landing, kerb strike.
  impact,

  /// Vertical shocks: kerbs, rough road.
  kerb,

  /// ABS working: a quick pulsing, like a real brake pedal.
  abs,
}

/// Turns telemetry into "road feel" vibrations. Pure, unit-tested.
/// Slip is stronger with more slip. At most one pulse every [minGap] so the
/// phone never buzzes constantly (impacts always go through).
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

  static const Set<HapticKind> all = {HapticKind.spin, HapticKind.lock, HapticKind.impact, HapticKind.kerb, HapticKind.abs};

  /// One ABS pulse; repeated at most every [minGap] while the ABS works,
  /// which gives the ~10 Hz pulsing of a real pedal.
  static const Pulse absPulse = Pulse(30, 170);

  Pulse? update(Telemetry t, DateTime now, {Set<HapticKind> enabled = all}) {
    final pulse = _compute(t, enabled);
    _gx = t.gx;
    _gy = t.gy;
    _gz = t.gz;
    if (pulse == null || strength <= 0) return null;
    if (pulse.durationMs < 100 && now.difference(_last) < minGap) return null;
    _last = now;
    return Pulse(pulse.durationMs, (pulse.amplitude * strength).round().clamp(1, 255));
  }

  static Pulse _slipPulse(double slip) {
    final intensity = ((slip - slipThreshold) / 12).clamp(0.0, 1.0);
    return Pulse(25, (60 + intensity * 160).round());
  }

  Pulse? _compute(Telemetry t, Set<HapticKind> enabled) {
    final gx = t.gx, gy = t.gy, gz = t.gz;
    if (enabled.contains(HapticKind.impact) &&
        gx != null && gy != null && gz != null && _gx != null && _gy != null && _gz != null) {
      final dx = gx - _gx!, dy = gy - _gy!, dz = gz - _gz!;
      final jolt = dx * dx + dy * dy + dz * dz;
      if (jolt > impactThreshold * impactThreshold) return const Pulse(140, 255);
    }
    if (t.absActive == true && enabled.contains(HapticKind.abs)) return absPulse;
    final lock = t.wheelLock ?? 0;
    final spin = t.wheelSpin ?? 0;
    if (lock > slipThreshold) {
      if (enabled.contains(HapticKind.lock)) return _slipPulse(lock);
    } else if (enabled.contains(HapticKind.spin)) {
      // Wheelspin, or sideways slide (also the only slip of older mods).
      final slip = spin > slipThreshold ? spin : (t.wheelSlip ?? 0);
      if (slip > slipThreshold) return _slipPulse(slip);
    }
    if (enabled.contains(HapticKind.kerb) && gz != null && ((gz.abs() - 9.81).abs() > rumbleThreshold)) {
      return const Pulse(18, 70);
    }
    return null;
  }
}
