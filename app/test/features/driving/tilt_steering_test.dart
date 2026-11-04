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

    expect(firstStep(fused: true), closeTo(0.5 * 30 / 75, 1e-6), reason: '30° of a 360° range (75° tilt)');
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

    test('reaches full lock with the 900° range (187.5° of tilt)', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), _rolled);
      expect(turn(s, 0, 185, _rolled), greaterThan(0.005));
      final (x, y, z) = _rolled(187.5);
      expect(s.steering(x, y, z), closeTo(0, 1e-9));
    });

    test('real wheel: 450° each way for 900°, through the ±180° seam', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true), upright);
      expect(turn(s, 0, 225, upright), closeTo(0.25, 1e-6));
      expect(turn(s, 230, 450, upright), closeTo(0, 1e-6));
      expect(turn(s, 445, 0, upright), closeTo(0.5, 1e-6), reason: 'back to the centre');
      expect(turn(s, -5, -450, upright), closeTo(1, 1e-6));
    });

    test('real wheel: full lock as the vehicle steering wheel', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true, vehicleLockDeg: 270), upright);
      expect(turn(s, 0, 135, upright), closeTo(0.25, 1e-6));
      expect(turn(s, 140, 270, upright), closeTo(0, 1e-6));
    });

    // The reported bug: after spinning the phone past full lock, the
    // calibrated position read as a turned wheel (the part of the spin
    // past full lock was lost).
    for (final range in [360.0, 540.0, 900.0]) {
      for (final spin in [100.0, 300.0, 725.0, 1180.0, 3600.0]) {
        test('$range° range: spun ${spin.toInt()}° either way, the calibrated position is the centre again', () {
          for (final dir in [1.0, -1.0]) {
            final s = rest(TiltSteering(rotationRangeDeg: range, smoothing: false), _rolled);
            turn(s, 0, dir * spin, _rolled);
            // Back the way it came...
            expect(turn(s, dir * (spin - 5), 0, _rolled), closeTo(0.5, 1e-6), reason: 'turned back, dir $dir');
            // ...or on to the next turn that brings it to the same place.
            final s2 = rest(TiltSteering(rotationRangeDeg: range, smoothing: false), _rolled);
            turn(s2, 0, dir * spin, _rolled);
            final next = (spin / 360).ceil() * 360.0;
            expect(turn(s2, dir * (spin + 5), dir * next, _rolled), closeTo(0.5, 1e-6), reason: 'turned on, dir $dir');
          }
        });
      }
    }

    test('no winding up: after ten turns the wheel follows the phone at once', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), _rolled);
      final at30 = turn(rest(TiltSteering(rotationRangeDeg: 900, smoothing: false), _rolled), 0, 30, _rolled);
      expect(turn(s, 0, 3600 + 30, _rolled), closeTo(at30, 1e-6));
      expect(turn(s, 3625, 3600, _rolled), closeTo(0.5, 1e-6));
    });

    test('past full lock the wheel stays there until the phone reaches the other full lock', () {
      final s = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false), _rolled); // 75° lock
      expect(turn(s, 0, 280, _rolled), closeTo(0, 1e-6), reason: 'held at full right');
      expect(turn(s, 285, 290, _rolled), closeTo(0.5 + 70 / 150, 1e-6), reason: '290° is 70° to the left');
      expect(turn(s, 295, 360, _rolled), closeTo(0.5, 1e-6));
      // Turning back from past full lock: full lock again, then the centre.
      final back = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false), _rolled);
      turn(back, 0, 200, _rolled);
      expect(turn(back, 195, 75, _rolled), closeTo(0, 1e-6));
      expect(turn(back, 70, 0, _rolled), closeTo(0.5, 1e-6));
    });

    test('real wheel: an overshoot under half a turn is kept exactly', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true, vehicleLockDeg: 540), upright);
      expect(turn(s, 0, 700, upright), closeTo(0, 1e-6));
      expect(turn(s, 695, 0, upright), closeTo(0.5, 1e-6));
    });

    test('real wheel: a long spin never winds up more than half a turn past full lock', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true, vehicleLockDeg: 540), upright);
      // Ten turns and a quarter: at most half a turn past full lock is kept
      // (whole turns come off), so 450° back (not 3690°) is the centre.
      expect(turn(s, 0, 3690, upright), closeTo(0.5 - 450 / 1080, 1e-6), reason: '450° of 540°');
      expect(turn(s, 3685, 3690 - 450, upright), closeTo(0.5, 1e-6));
    });

    test('another vehicle with a smaller full lock does not shift the centre', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true, vehicleLockDeg: 540), upright);
      turn(s, 0, 200, upright);
      s.vehicleLockDeg = 150;
      expect(turn(s, 200, 200, upright), closeTo(0, 1e-6), reason: 'past the new full lock');
      // The old code clamped the roll to 150°: back here it read 50° left.
      expect(turn(s, 195, 0, upright), closeTo(0.5, 1e-6));
    });

    test('accelerometer smoothing does not sweep across when a turn comes off', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900), _rolled); // smoothed
      turn(s, 0, 3600, _rolled);
      // A few samples at rest after the spin settle on the centre.
      var v = 0.0;
      for (var i = 0; i < 30; i++) {
        final (x, y, z) = _rolled(0);
        v = s.steering(x, y, z);
      }
      expect(v, closeTo(0.5, 1e-3));
    });

    test('overshootDegFor', () {
      expect(TiltSteering.overshootDegFor(75), 210);
      expect(TiltSteering.overshootDegFor(187.5), 0);
      expect(TiltSteering.overshootDegFor(450), 180);
    });

    test('a phone held along the steering axis keeps its last angle', () {
      final s = rest(TiltSteering(rotationRangeDeg: 360, smoothing: false), _rolled);
      final before = turn(s, 0, 30, _rolled);
      expect(s.steering(9.81, 0, 0), before, reason: 'gravity along x: no roll to read');
    });

    test('turning the phone never reads as a pitch gesture', () {
      final s = rest(TiltSteering(rotationRangeDeg: 900, smoothing: false, realWheel: true), upright);
      for (final deg in [30.0, 90.0, 200.0]) {
        final (x, y, z) = upright(deg);
        expect(s.pitch(x, y, z).abs(), lessThan(1e-6), reason: '$deg°');
      }
      // Tipping the top of the upright phone towards the player is a pitch.
      expect(s.pitch(9.81 * math.cos(0.5), 0, 9.81 * math.sin(0.5)).abs(), greaterThan(25));
    });

    test('full lock angle of each mode', () {
      expect(TiltSteering.fullLockDegFor(900), 187.5);
      expect(TiltSteering.fullLockDegFor(900, realWheel: true), 450);
      expect(TiltSteering.fullLockDegFor(900, realWheel: true, vehicleLockDeg: 540), 540);
    });
  });
}
