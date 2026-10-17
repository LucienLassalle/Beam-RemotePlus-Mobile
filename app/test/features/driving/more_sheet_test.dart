import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/vehicle_command.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('only the Road theme has the More button', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    expect(find.text('MORE'), findsNothing);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);
    expect(find.text('MORE'), findsOneWidget);
  });

  testWidgets('the More sheet lists, presses and holds the vehicle commands', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);
    await tester.tap(find.text('MORE'));
    await tester.pump();
    expect(link.commands, ['actions']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    link.events_.add(const ActionsMessage(vehicle: 'pickup', commands: [
      VehicleCommand(id: 'g:four_wd'),
      VehicleCommand(id: 'v:crane', hold: true, title: 'Crane up'),
    ]));
    await tester.pumpAndSettle();
    expect(find.text('4WD'), findsOneWidget);
    expect(find.text('Crane up'), findsOneWidget);

    await tester.tap(find.text('4WD'));
    expect(link.commands.last, 'action|g:four_wd');

    final gesture = await tester.startGesture(tester.getCenter(find.text('Crane up')));
    await tester.pump();
    expect(link.commands.last, 'action_down|v:crane');
    await gesture.up();
    await tester.pump();
    expect(link.commands.last, 'action_up|v:crane');
  });

  testWidgets('tells to update an older mod that does not answer', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);
    await tester.tap(find.text('MORE'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.textContaining('update the Beam-RemotePlus mod'), findsOneWidget);
  });
}
