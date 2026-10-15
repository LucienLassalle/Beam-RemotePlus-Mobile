import 'package:beam_remoteplus/themes/kit/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';

/// A dashboard with one button in the middle of the brake half and big text
/// elsewhere: only the button may take touches.
class _ButtonTheme extends ControlTheme {
  const _ButtonTheme();

  @override
  String get name => 'Button test';

  @override
  String get author => 'test';

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) => Row(children: [
        Expanded(
          child: Center(
            child: DashboardButton(
              command: 'signal_left',
              onCommand: data.onCommand,
              child: const Icon(Icons.arrow_back, size: 34),
            ),
          ),
        ),
        const Expanded(child: Center(child: Text('120', style: TextStyle(fontSize: 120)))),
      ]);
}

void main() {
  testWidgets('a dashboard button sends its command and presses no pedal', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: const _ButtonTheme(), link: link);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(DashboardButton)));
    await tester.pump();
    expect(link.brake, 0);
    await gesture.up();
    await tester.pump();
    expect(link.commands, ['signal_left']);
  });

  testWidgets('the rest of the dashboard, text included, still presses the pedals', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: const _ButtonTheme(), link: link);
    final beside = tester.getCenter(find.byType(DashboardButton)) + const Offset(0, 80);
    var gesture = await tester.startGesture(beside);
    await tester.pump();
    expect(link.brake, greaterThan(0));
    await gesture.up();
    gesture = await tester.startGesture(tester.getCenter(find.text('120')));
    await tester.pump();
    expect(link.throttle, greaterThan(0));
    await gesture.up();
    expect(link.commands, isEmpty);
  });

  testWidgets('without the mod the button is only drawn', (tester) async {
    final link = FakeLink(modActive: false);
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: const _ButtonTheme(), link: link);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(DashboardButton)));
    await tester.pump();
    expect(link.brake, greaterThan(0));
    await gesture.up();
    expect(link.commands, isEmpty);
  });
}
