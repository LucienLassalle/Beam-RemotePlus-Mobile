import 'package:beam_remoteplus/features/driving/widgets/top_bar.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('shows the round trip to the mod next to "Connected"', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    expect(find.text('Connected'), findsOneWidget);

    link.latencyMs = 12;
    link.quality_.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Connected · 12 ms'), findsOneWidget);
  });

  testWidgets('says when the signal is lost', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    link
      ..latencyMs = 12
      ..signalLost = true;
    link.quality_.add(null);
    await tester.pump();
    await tester.pump();
    expect(find.text('Signal lost'), findsOneWidget);
  });

  test('the dot turns amber, then orange, as the round trip grows', () {
    expect(StatusChip.latencyColor(null), Colors.greenAccent);
    expect(StatusChip.latencyColor(20), Colors.greenAccent);
    expect(StatusChip.latencyColor(StatusChip.slowMs), Colors.amberAccent);
    expect(StatusChip.latencyColor(StatusChip.verySlowMs), Colors.orangeAccent);
  });
}
