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

  test('centre at rest, the phone turns 1:1 with the wheel', () {
    final s = calibrated();
    var (x, y, z) = _rolled(0);
    expect(s.steering(x, y, z), 0.5);
    (x, y, z) = _rolled(90); // 360° range: full lock at 180°, so half lock
    expect(s.steering(x, y, z), closeTo(0.25, 1e-6));
  });

  test('invert flips the direction', () {
    final s = calibrated(invert: true);
    final (x, y, z) = _rolled(90);
    expect(s.steering(x, y, z), closeTo(0.75, 1e-6));
  });

  test('bigger rotation range needs more tilt', () {
    final s = calibrated(range: 900);
    final (x, y, z) = _rolled(75);
    expect(s.steering(x, y, z), closeTo(0.5 - 75 / 900, 1e-6));
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

  test('touchWheelMaxDegFor', () {
    expect(TiltSteering.touchWheelMaxDegFor(360), 75);
    expect(TiltSteering.touchWheelMaxDegFor(900), 187.5);
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

  test('the gyroscope-based samples are never smoothed: no delay', () {
    double firstStep({required bool fused}) {
      final s = TiltSteering(rotationRangeDeg: 360, smoothing: true, fused: fused);
      for (var i = 0; i < TiltSteering.calibrationSamples; i++) {
        final (x, y, z) = _rolled(0);
        s.steering(x, y, z);
      }
      s.steering(0, 0, 9.81); // first smoothed sample at rest
      final (x, y, z) = _rolled(30);
      return 0.5 - s.steering(x, y, z);
    }

    expect(firstStep(fused: true), closeTo(0.5 * 30 / 180, 1e-6), reason: '30° of a 360° range (full lock at 180°)');
    expect(firstStep(fused: false), lessThan(firstStep(fused: true)));
  });

  group('full rotation', () {
    // Turns a calibrated phone from [from] to [to] degrees in 5° steps, as
    // the sensor would report a continuous rotation; returns the last value.
    double turn(TiltSteering s, double from, double to, (double, double, double) Function(double) at) {
      var value = 0.5;
      final step = to > from ? 5.0 : -5.0;
      for (var a = from; step > 0 ? a <= to : a >= to; a += step) {
        final (x, y, z) = at(a);
        value = s.steering(x, y, z);
      }
      return value;
    }

    TiltSteering rest(TiltSteering s, (double, double, double) Function(double) at) {
      for (var i = 0; i < TiltSteering.calibrationSamples; i++) {
        final (x, y, z) = at(0);
        s.steering(x, y, z);
      }
      return s;
    }

    // Phone held upright like a wheel, screen towards the player: gravity
    // along x at rest, turning moves it towards y.
    (double, double, double) upright(double deg) {
      final r = deg * math.pi / 180;
      return (9.81 * math.cos(r), 9.81 * math.sin(r), 0);
    }

    test('keeps turning past 90° instead of folding back', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), _rolled);
      final at90 = turn(s, 0, 90, _rolled);
      final at150 = turn(s, 95, 150, _rolled);
      expect(at150, lessThan(at90), reason: 'further from the centre, not back towards it');
    });

    test('900°: 450° each way, through the ±180° seam', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), upright);
      expect(turn(s, 0, 225, upright), closeTo(0.25, 1e-6));
      expect(turn(s, 230, 450, upright), closeTo(0, 1e-6));
      expect(turn(s, 445, 0, upright), closeTo(0.5, 1e-6), reason: 'back to the centre');
      expect(turn(s, -5, -450, upright), closeTo(1, 1e-6));
    });

    // The behaviour asked for: like a car whose steering wheel has no
    // hard stop. Past full lock the wheel stays at full lock while the
    // phone is beyond it, even turning back, and steers back only once the
    // phone is back within full lock.
    for (final range in [360.0, 540.0, 720.0, 900.0]) {
      final lock = range / 2;
      test('${range.toInt()}°: held at full lock beyond ${lock.toInt()}°, steers back once within it', () {
        for (final dir in [1.0, -1.0]) {
          final full = dir > 0 ? 0.0 : 1.0;
          final s = rest(TiltSteering(rotationRangeDeg: range, smoothing: false), upright);
          expect(turn(s, 0, dir * lock, upright), closeTo(full, 1e-6), reason: 'full lock');
          expect(turn(s, dir * (lock + 5), dir * (lock + 200), upright), closeTo(full, 1e-6), reason: 'still turning');
          expect(turn(s, dir * (lock + 195), dir * (lock + 20), upright), closeTo(full, 1e-6),
              reason: 'turned back, still beyond full lock');
          expect(turn(s, dir * (lock + 15), dir * lock / 2, upright), closeTo(0.5 - dir * 0.25, 1e-6),
              reason: 'back within full lock: half lock');
          expect(turn(s, dir * (lock / 2 - 5), 0, upright), closeTo(0.5, 1e-6), reason: 'calibrated position');
        }
      });
    }

    test('three turns past full lock need three turns back, then the centre', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), upright);
      turn(s, 0, 450 + 1080, upright);
      expect(turn(s, 1525, 455, upright), closeTo(0, 1e-6), reason: 'beyond 450° all the way back');
      expect(turn(s, 450, 0, upright), closeTo(0.5, 1e-6));
    });

    test('Auto: full lock as the vehicle steering wheel', () {
      final s = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false, autoRange: true, vehicleLockDeg: 270), upright);
      expect(turn(s, 0, 135, upright), closeTo(0.25, 1e-6));
      expect(turn(s, 140, 270, upright), closeTo(0, 1e-6));
    });

    test('Auto with an older mod (vehicle unknown): 450° each way', () {
      final s = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false, autoRange: true), upright);
      expect(turn(s, 0, 225, upright), closeTo(0.25, 1e-6));
    });

    test('Auto: another vehicle with a smaller full lock does not shift the centre', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, autoRange: true, vehicleLockDeg: 540), upright);
      turn(s, 0, 200, upright);
      s.vehicleLockDeg = 150;
      expect(turn(s, 200, 200, upright), closeTo(0, 1e-6), reason: 'past the new full lock');
      expect(turn(s, 195, 0, upright), closeTo(0.5, 1e-6));
    });

    test('a phone held along the steering axis keeps its last angle', () {
      final s = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false), _rolled);
      final before = turn(s, 0, 30, _rolled);
      expect(s.steering(9.81, 0, 0), before, reason: 'gravity along x: no roll to read');
    });

    test('turning the phone never reads as a pitch gesture', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), upright);
      for (final deg in [30.0, 90.0, 200.0]) {
        final (x, y, z) = upright(deg);
        expect(s.pitch(x, y, z).abs(), lessThan(1e-6), reason: '$deg°');
      }
      // Tipping the top of the upright phone towards the player is a pitch.
      expect(s.pitch(9.81 * math.cos(0.5), 0, 9.81 * math.sin(0.5)).abs(), greaterThan(25));
    });

    test('full lock angle', () {
      expect(TiltSteering.fullLockDegFor(900), 450);
      expect(TiltSteering.fullLockDegFor(360), 180);
      expect(TiltSteering.fullLockDegFor(360, auto: true), 450);
      expect(TiltSteering.fullLockDegFor(360, auto: true, vehicleLockDeg: 540), 540);
    });
  });
}
