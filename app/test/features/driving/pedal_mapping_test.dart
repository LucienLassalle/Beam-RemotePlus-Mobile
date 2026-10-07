import 'package:beam_remoteplus/features/driving/pedal_mapping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PedalMapping.wide (tilt steering)', () {
    const m = PedalMapping.wide;
    test('40% of the width on each side, the middle 20% is free', () {
      expect(m.pedalAt(0, 1000), Pedal.brake);
      expect(m.pedalAt(399, 1000), Pedal.brake);
      expect(m.pedalAt(450, 1000), isNull);
      expect(m.pedalAt(550, 1000), isNull);
      expect(m.pedalAt(600, 1000), Pedal.throttle);
      expect(m.pedalAt(999, 1000), Pedal.throttle);
    });
    test('the travel uses 80% of the height and still reaches 100%', () {
      expect(m.valueAt(100, 1000), 1); // top 15%
      expect(m.valueAt(160, 1000), closeTo(0.9875, 1e-3));
      expect(m.valueAt(960, 1000), 0); // bottom 5%
      expect(1 - m.topDeadZone - m.bottomDeadZone, closeTo(0.8, 1e-9));
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
