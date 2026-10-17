import 'package:beam_remoteplus/features/driving/steering_curve.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0 % keeps the steering linear', () {
    for (final v in [0.0, 0.2, 0.5, 0.73, 1.0]) {
      expect(SteeringCurve.apply(v, 0), v);
    }
  });

  test('centre and full lock never move', () {
    for (final p in [0.3, 1.0]) {
      expect(SteeringCurve.apply(0.5, p), 0.5);
      expect(SteeringCurve.apply(0, p), closeTo(0, 1e-9));
      expect(SteeringCurve.apply(1, p), closeTo(1, 1e-9));
    }
  });

  test('more precision = smaller moves around the centre, on both sides', () {
    final left = SteeringCurve.apply(0.75, 1); // half lock to the left
    expect(left, lessThan(0.75));
    expect(left, greaterThan(0.5));
    expect(SteeringCurve.apply(0.25, 1), closeTo(1 - left, 1e-9));
    expect(SteeringCurve.apply(0.75, 0.5), greaterThan(left));
  });
}
