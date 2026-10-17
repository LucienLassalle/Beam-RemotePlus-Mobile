import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/features/driving/wheel_gesture.dart';
import 'package:beam_remoteplus/features/driving/widgets/touch_wheel.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  group('WheelGesture', () {
    test('follows the finger without jumping where it lands', () {
      final w = WheelGesture(maxAngleDeg: 90)..start(-90);
      expect(w.steering, 0.5);
      w.move(-45); // a quarter of the way clockwise: turning right
      expect(w.angleDeg, 45);
      expect(w.steering, 0.75);
    });

    test('crosses the ±180° seam and stops at full lock', () {
      final w = WheelGesture(maxAngleDeg: 90)
        ..start(170)
        ..move(-170); // +20° through the seam
      expect(w.angleDeg, 20);
      w
        ..move(-90)
        ..move(0)
        ..move(90);
      expect(w.angleDeg, 90);
      expect(w.steering, 1);
    });

    test('a new touch continues from the current angle', () {
      final w = WheelGesture(maxAngleDeg: 90)
        ..start(0)
        ..move(-30)
        ..end()
        ..start(100);
      expect(w.angleDeg, -30);
      expect(w.steering, closeTo(0.5 - 30 / 180, 1e-9));
    });
  });

  testWidgets('the wheel mode steers, then comes back to the centre', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester,
        theme: themeByName('Default'), link: link, settings: const AppSettings(tiltSteering: false, touchWheel: true));
    final wheel = find.byType(TouchWheel);
    expect(wheel, findsOneWidget);
    expect(tester.getCenter(wheel).dx, lessThan(phoneSize.width / 3), reason: 'under the left thumb');
    final centre = tester.getCenter(wheel);
    final gesture = await tester.startGesture(centre + const Offset(-50, 0)); // left of the hub
    await gesture.moveTo(centre + const Offset(-35, -35), timeStamp: const Duration(milliseconds: 20));
    await gesture.moveTo(centre + const Offset(0, -50), timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    expect(link.steering, greaterThan(0.5), reason: 'turned clockwise = right, like the right of the touch bar');
    await gesture.up();
    await tester.pump();
    await tester.pump(TouchWheel.returnDuration);
    await tester.pump(const Duration(milliseconds: 50));
    expect(link.steering, closeTo(0.5, 1e-6));
  });
}
