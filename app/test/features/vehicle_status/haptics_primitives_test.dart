import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/features/vehicle_status/haptics_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final t0 = DateTime(2026);

  test('each road event asks for its own vibration shape', () {
    final engine = HapticsEngine();
    expect(engine.update(const Telemetry(absActive: true), t0)?.primitive, HapticPrimitive.tick);

    final kerbs = HapticsEngine();
    expect(kerbs.update(const Telemetry(gx: 0, gy: 0, gz: 16), t0)?.primitive, HapticPrimitive.lowTick);

    final crash = HapticsEngine();
    crash.update(const Telemetry(gx: 0, gy: 0, gz: 9.81), t0);
    final hit = crash.update(const Telemetry(gx: 40, gy: 0, gz: 9.81), t0.add(const Duration(seconds: 1)));
    expect(hit?.primitive, HapticPrimitive.thud);
  });

  test('wheelspin stays a plain pulse, and the strength scales the shape too', () {
    final engine = HapticsEngine(strength: 0.5);
    final spin = engine.update(const Telemetry(wheelSpin: 10), t0);
    expect(spin?.primitive, isNull);
    final abs = HapticsEngine(strength: 0.5).update(const Telemetry(absActive: true), t0)!;
    expect(abs.amplitude, (HapticsEngine.absPulse.amplitude * 0.5).round());
    expect(abs.primitive, HapticPrimitive.tick);
  });
}
