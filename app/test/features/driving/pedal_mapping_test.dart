import 'package:beam_remoteplus/features/driving/pedal_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PedalMapping.halves (tilt steering)', () {
    const m = PedalMapping.halves;
    test('every point of the screen is a pedal', () {
      for (var x = 0.0; x < 1000; x += 50) {
        expect(m.pedalAt(x, 1000), isNotNull, reason: 'x=$x');
      }
      expect(m.pedalAt(499, 1000), Pedal.brake);
      expect(m.pedalAt(500, 1000), Pedal.throttle);
    });
  });

  group('PedalMapping.sides (touch steering)', () {
    const m = PedalMapping.sides;
    test('leaves the middle free for the steering bar', () {
      expect(m.pedalAt(100, 1000), Pedal.brake);
      expect(m.pedalAt(500, 1000), isNull);
      expect(m.pedalAt(900, 1000), Pedal.throttle);
    });
  });

  group('valueAt', () {
    const m = PedalMapping(topDeadZone: 0.1, bottomDeadZone: 0.1);
    test('dead zones give exactly 0 and 1', () {
      expect(m.valueAt(5, 100), 1);
      expect(m.valueAt(95, 100), 0);
    });
    test('linear in between', () {
      expect(m.valueAt(50, 100), closeTo(0.5, 1e-9));
      expect(m.valueAt(30, 100), closeTo(0.75, 1e-9));
    });
    test('degenerate sizes', () {
      expect(m.valueAt(10, 0), 0);
      expect(m.pedalAt(10, 0), isNull);
    });
  });
}
