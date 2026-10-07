import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';

/// Regression test for "on F4 and Civetta you have to touch outside the
/// dashboard to brake or accelerate": on every theme, touching anywhere on
/// the dashboard must press a pedal.
void main() {
  for (final theme in availableThemes) {
    group('${theme.name} theme', () {
      testWidgets('touches over the dashboard press the pedals', (tester) async {
        final link = FakeLink();
        addTearDown(link.dispose);
        await pumpDrivingView(tester, theme: theme, link: link);
        link.telemetry_.add(sampleTelemetry);
        await tester.pump();

        // Points spread over the dashboard area (away from the button rows).
        for (final fx in [0.05, 0.2, 0.3, 0.38]) {
          for (final fy in [0.3, 0.5, 0.7]) {
            final gesture = await tester.startGesture(Offset(phoneSize.width * fx, phoneSize.height * fy));
            await tester.pump();
            expect(link.brake, greaterThan(0), reason: 'brake at ($fx, $fy)');
            expect(link.throttle, 0);
            await gesture.up();
            await tester.pump();
            expect(link.brake, 0);
          }
        }
        for (final fx in [0.62, 0.7, 0.8, 0.95]) {
          for (final fy in [0.3, 0.5, 0.7]) {
            final gesture = await tester.startGesture(Offset(phoneSize.width * fx, phoneSize.height * fy));
            await tester.pump();
            expect(link.throttle, greaterThan(0), reason: 'throttle at ($fx, $fy)');
            await gesture.up();
            await tester.pump();
          }
        }
      });

      testWidgets('brake and throttle work together (two thumbs)', (tester) async {
        final link = FakeLink();
        addTearDown(link.dispose);
        await pumpDrivingView(tester, theme: theme, link: link);
        final left = await tester.startGesture(const Offset(200, 150));
        final right = await tester.startGesture(const Offset(700, 150));
        await tester.pump();
        expect(link.brake, greaterThan(0.5));
        expect(link.throttle, greaterThan(0.5));
        await left.up();
        await right.up();
      });

      testWidgets('buttons take their own touches, not the pedals', (tester) async {
        final link = FakeLink();
        addTearDown(link.dispose);
        await pumpDrivingView(tester, theme: theme, link: link);
        await tester.tap(find.byIcon(Icons.flip_camera_android));
        await tester.pump();
        expect(link.commands, ['cam_next']);
        expect(link.brake, 0);
        expect(link.throttle, 0);
      });
    });
  }

  testWidgets('touch steering keeps the middle of the screen for the steering bar', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: availableThemes.first, link: link, settings: const AppSettings(tiltSteering: false));
    final gesture = await tester.startGesture(Offset(phoneSize.width / 2, 200));
    await tester.pump();
    expect(link.brake + link.throttle, 0);
    await gesture.up();
    await tester.tap(find.byType(GestureDetector).first, warnIfMissed: false);
  });

  testWidgets('the Default theme stays clean, Road offers every vehicle button', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    expect(find.byIcon(Icons.campaign), findsNothing); // horn button
    expect(find.byIcon(Icons.tune), findsNothing); // drive mode button
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);
    await tester.tap(find.byIcon(Icons.warning_amber).last);
    expect(link.commands, ['hazard']);
  });

  testWidgets('vehicle buttons hidden in the settings disappear', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester,
        theme: themeByName('Road'), link: link, settings: const AppSettings(hiddenActions: {'hazard', 'cruise'}));
    expect(find.byIcon(Icons.warning_amber), findsNothing);
    expect(find.byIcon(Icons.campaign), findsOneWidget);
  });

  testWidgets('second-screen mode shows no controls', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link, settings: const AppSettings(secondScreen: true));
    expect(find.byIcon(Icons.restart_alt), findsNothing);
    expect(find.byIcon(Icons.flip_camera_android), findsNothing);
    final gesture = await tester.startGesture(const Offset(100, 200));
    await tester.pump();
    expect(link.brake, 0);
    await gesture.up();
  });

  testWidgets('read-only mode ignores the pedals', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    final controller = await pumpDrivingView(tester, theme: availableThemes.first, link: link);
    controller.setReadOnly(true);
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(200, 200));
    await tester.pump();
    expect(link.brake, 0);
    await gesture.up();
  });
}
