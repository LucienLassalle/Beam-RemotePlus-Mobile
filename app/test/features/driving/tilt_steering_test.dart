import 'dart:math' as math;

import 'package:beam_remoteplus/features/driving/tilt_steering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accelerometer sample of a phone rolled by [deg] degrees (landscape).
(double, double, double) _rolled(double deg) {
  final r = deg * math.pi / 180;
  return (0, 9.81 * math.sin(r), 9.81 * math.cos(r));
}

void main() {
  TiltSteering calibrated({double range = 360, bool invert = false, bool smoothing = false}) {
    final s = TiltSteering(rotationRangeDeg: range, invert: invert, smoothing: smoothing);
    for (var i = 0; i < TiltSteering.calibrationSamples; i++) {
      final (x, y, z) = _rolled(0);
      expect(s.steering(x, y, z), 0.5);
    }
    expect(s.calibrated, isTrue);
    return s;
  }

  test('centre at rest, full lock at the configured tilt', () {
    final s = calibrated();
    var (x, y, z) = _rolled(0);
    expect(s.steering(x, y, z), 0.5);
    (x, y, z) = _rolled(75); // 360° range -> 75° for full lock
    expect(s.steering(x, y, z), closeTo(0, 1e-6));
  });

  test('invert flips the direction', () {
    final s = calibrated(invert: true);
    final (x, y, z) = _rolled(75);
    expect(s.steering(x, y, z), closeTo(1, 1e-6));
  });

  test('bigger rotation range needs more tilt', () {
    final s = calibrated(range: 900);
    final (x, y, z) = _rolled(75);
    expect(s.steering(x, y, z), closeTo(0.3, 1e-2));
  });

  test('ignores free-fall samples', () {
    expect(calibrated().steering(0, 0, 0.1), 0.5);
  });

  test('a shake moves the wheel much less than the same rotation', () {
    final calm = calibrated(smoothing: true);
    final shaken = calibrated(smoothing: true);
    final (x, y, z) = _rolled(20);
    final calmValue = calm.steering(x, y, z);
    final shakenValue = shaken.steering(x * 2, y * 2, z * 2 + 5); // strong linear jolt
    expect((shakenValue - 0.5).abs(), lessThan((calmValue - 0.5).abs()));
  });

  test('maxTiltDegFor', () {
    expect(TiltSteering.maxTiltDegFor(360), 75);
    expect(TiltSteering.maxTiltDegFor(900), 187.5);
  });

  group('PitchShifter', () {
    test('shifts once per gesture, re-arms in the neutral zone, respects the cooldown', () {
      final p = PitchShifter();
      final t0 = DateTime(2026);
      expect(p.update(-30, t0), 1);
      expect(p.update(-30, t0.add(const Duration(seconds: 1))), 0); // still tilted
      expect(p.update(0, t0.add(const Duration(seconds: 1))), 0); // re-armed
      expect(p.update(30, t0.add(const Duration(milliseconds: 1200))), -1);
      expect(p.update(0, t0.add(const Duration(milliseconds: 1250))), 0);
      expect(p.update(-30, t0.add(const Duration(milliseconds: 1300))), 0); // cooldown
    });
  });
}
