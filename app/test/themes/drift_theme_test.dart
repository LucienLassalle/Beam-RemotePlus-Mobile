import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/themes/drift/drift_theme.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';

void main() {
  testWidgets('shows the drift angle, whatever its side', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Drift'), link: link);
    link.telemetry_.add(const Telemetry(driftAngle: -41.6));
    await tester.pump();
    await tester.pump();
    expect(find.text('42°'), findsOneWidget);
  });

  testWidgets('the handbrake works while held', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Drift'), link: link);
    final gesture = await tester.startGesture(tester.getCenter(find.byTooltip('Handbrake (hold)')));
    await tester.pump();
    expect(link.commands, ['handbrake|1']);
    expect(link.brake, 0, reason: 'the brake pedal under it is not pressed');
    await gesture.up();
    await tester.pump();
    expect(link.commands, ['handbrake|1', 'handbrake|0']);
  });

  testWidgets('other themes have no handbrake button', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);
    expect(find.byTooltip('Handbrake (hold)'), findsNothing);
  });

  test('the angle turns amber, then red, as the slide grows', () {
    expect(DriftTheme.angleColor(null), Colors.white);
    expect(DriftTheme.angleColor(-5), Colors.white);
    expect(DriftTheme.angleColor(20), Colors.amberAccent);
    expect(DriftTheme.angleColor(-50), Colors.deepOrangeAccent);
  });
}
