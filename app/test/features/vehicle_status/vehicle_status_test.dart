import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/features/vehicle_status/haptics_engine.dart';
import 'package:beam_remoteplus/features/vehicle_status/warnings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('activeWarnings', () {
    test('none for a healthy running car', () {
      expect(activeWarnings(const Telemetry(engineRunning: true, ignitionLevel: 2, waterTemp: 90, lowFuel: false)), isEmpty);
    });

    test('maps telemetry and engine failures to dashboard lights, severe first', () {
      final w = activeWarnings(const Telemetry(
        waterTemp: 120,
        lowFuel: true,
        engineDamage: ['radiatorLeak', 'oilpanLeak'],
        flatTires: ['FL'],
        parkingBrake: true,
        speed: 10,
      ));
      expect(w.first, VehicleWarning.overheating);
      expect(w, containsAll([
        VehicleWarning.oilPressure,
        VehicleWarning.checkEngine,
        VehicleWarning.flatTire,
        VehicleWarning.parkingBrakeWhileMoving,
        VehicleWarning.lowFuel,
      ]));
      expect(w, isNot(contains(VehicleWarning.lowTirePressure)));
    });

    test('battery light when the engine stalled with the ignition on', () {
      expect(activeWarnings(const Telemetry(engineRunning: false, ignitionLevel: 2)), [VehicleWarning.engineStopped]);
      expect(activeWarnings(const Telemetry(engineRunning: false, ignitionLevel: 0)), isEmpty);
    });

    test('parking brake is only a warning while moving', () {
      expect(activeWarnings(const Telemetry(parkingBrake: true, speed: 0)), isEmpty);
    });

    test('critical vs check-soon', () {
      expect(isCritical(VehicleWarning.oilPressure), isTrue);
      expect(isCritical(VehicleWarning.lowFuel), isFalse);
    });
  });

  group('HapticsEngine', () {
    final t0 = DateTime(2026);
    test('quiet while cruising', () {
      final h = HapticsEngine();
      expect(h.update(const Telemetry(gx: 0, gy: 0, gz: -9.8, wheelSlip: 0.2), t0), isNull);
      expect(h.update(const Telemetry(gx: 0.5, gy: 0, gz: -9.8, wheelSlip: 0.3), t0.add(const Duration(seconds: 1))), isNull);
    });

    test('a crash gives a long strong pulse', () {
      final h = HapticsEngine();
      h.update(const Telemetry(gx: 0, gy: 0, gz: -9.8), t0);
      final p = h.update(const Telemetry(gx: 30, gy: 5, gz: -9.8), t0.add(const Duration(milliseconds: 30)));
      expect(p!.durationMs, greaterThanOrEqualTo(100));
      expect(p.amplitude, 255);
    });

    test('wheelspin vibrates harder with more slip, at a limited rate', () {
      final h = HapticsEngine();
      final soft = h.update(const Telemetry(wheelSlip: 3), t0)!;
      expect(h.update(const Telemetry(wheelSlip: 20), t0.add(const Duration(milliseconds: 20))), isNull);
      final hard = h.update(const Telemetry(wheelSlip: 20), t0.add(const Duration(milliseconds: 200)))!;
      expect(hard.amplitude, greaterThan(soft.amplitude));
    });

    test('kerbs rumble, strength scales everything, 0 disables', () {
      final h = HapticsEngine(strength: 0.5);
      expect(h.update(const Telemetry(gz: -16), t0)!.amplitude, 35);
      h.strength = 0;
      expect(h.update(const Telemetry(gz: -16), t0.add(const Duration(seconds: 1))), isNull);
    });
  });
}
