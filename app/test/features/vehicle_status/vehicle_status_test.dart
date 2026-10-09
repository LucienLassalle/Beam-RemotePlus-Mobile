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

    test('clutch, drivetrain and fuel tank warnings', () {
      expect(activeWarnings(const Telemetry(clutchState: 'hot')), [VehicleWarning.clutchOverheating]);
      expect(activeWarnings(const Telemetry(clutchState: 'overheating')), [VehicleWarning.clutchOverheating]);
      expect(activeWarnings(const Telemetry(clutchState: 'damaged')), [VehicleWarning.clutchDamaged]);
      expect(activeWarnings(const Telemetry(brokenParts: ['wheelaxleRL'])), [VehicleWarning.drivetrainBroken]);
      expect(activeWarnings(const Telemetry(brokenParts: ['mainEngine'])), isEmpty);
      expect(activeWarnings(const Telemetry(fuelLeak: true)), [VehicleWarning.fuelLeak]);
      expect(isCritical(VehicleWarning.drivetrainBroken), isTrue);
      expect(isCritical(VehicleWarning.clutchOverheating), isFalse);
    });

    test('no low tyre pressure warning for a car running its normal low pressures', () {
      const f4 = Telemetry(tirePressures: {'FL': 100, 'FR': 101}, tirePressuresNominal: {'FL': 110, 'FR': 110});
      expect(activeWarnings(f4), isEmpty);
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

    test('wheelspin and locked wheels are told apart and switched off separately', () {
      final h = HapticsEngine();
      const locked = Telemetry(wheelSlip: 15, wheelLock: 15, wheelSpin: 0);
      expect(h.update(locked, t0, enabled: {HapticKind.spin}), isNull);
      expect(h.update(locked, t0.add(const Duration(seconds: 1)), enabled: {HapticKind.lock}), isNotNull);
      const spinning = Telemetry(wheelSlip: 8, wheelSpin: 8, wheelLock: 0);
      expect(h.update(spinning, t0.add(const Duration(seconds: 2)), enabled: {HapticKind.lock}), isNull);
      expect(h.update(spinning, t0.add(const Duration(seconds: 3)), enabled: {HapticKind.spin}), isNotNull);
    });

    test('impacts and kerbs can be switched off', () {
      final h = HapticsEngine();
      h.update(const Telemetry(gx: 0, gy: 0, gz: -9.8), t0);
      expect(h.update(const Telemetry(gx: 30, gy: 0, gz: -9.8), t0.add(const Duration(seconds: 1)), enabled: {}), isNull);
      expect(h.update(const Telemetry(gz: -16), t0.add(const Duration(seconds: 2)), enabled: {HapticKind.spin}), isNull);
    });

    test('kerbs rumble, strength scales everything, 0 disables', () {
      final h = HapticsEngine(strength: 0.5);
      expect(h.update(const Telemetry(gz: -16), t0)!.amplitude, 35);
      h.strength = 0;
      expect(h.update(const Telemetry(gz: -16), t0.add(const Duration(seconds: 1))), isNull);
    });
  });
}
