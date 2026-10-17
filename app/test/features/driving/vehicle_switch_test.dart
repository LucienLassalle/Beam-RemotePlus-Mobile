import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('a tap on the vehicle switch does nothing', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    await tester.tap(find.byTooltip('Next vehicle (hold)'));
    await tester.pump(const Duration(milliseconds: 700));
    expect(link.commands, isEmpty);
  });

  testWidgets('holding it switches the vehicle once', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    final gesture = await tester.startGesture(tester.getCenter(find.byTooltip('Previous vehicle (hold)')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(link.commands, isEmpty);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(link.commands, ['prev_vehicle']);
    await gesture.up();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
