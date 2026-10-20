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

  group('PedalMapping.rightThumb (thumb wheel)', () {
    const m = PedalMapping.rightThumb;
    test('brake then throttle side by side on the right, the left free for the wheel', () {
      expect(m.pedalAt(100, 1000), isNull);
      expect(m.pedalAt(500, 1000), isNull);
      expect(m.pedalAt(650, 1000), Pedal.brake);
      expect(m.pedalAt(850, 1000), Pedal.throttle);
      expect(m.pedalAt(1000, 1000), Pedal.throttle);
    });
  });

  group('PedalMapping.video (over the video)', () {
    const m = PedalMapping.video;
    test('a quarter of the width on each side, the middle half turns the camera', () {
      expect(m.pedalAt(249, 1000), Pedal.brake);
      expect(m.pedalAt(300, 1000), isNull);
      expect(m.pedalAt(700, 1000), isNull);
      expect(m.pedalAt(750, 1000), Pedal.throttle);
      expect(m.freeSpan, (0.25, 0.75));
    });
    test('the free span of the thumb wheel layout is on the left', () {
      expect(PedalMapping.rightThumb.freeSpan, (0, 0.6));
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
