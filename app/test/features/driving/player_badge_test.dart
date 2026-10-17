import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/features/driving/widgets/player_badge.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('shows the player number in the player colour', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    expect(find.byType(PlayerBadge), findsNothing, reason: 'not assigned yet');
    link.telemetry_.add(const Telemetry(player: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('P2'), findsOneWidget);
    final box = tester.widget<Container>(find.descendant(of: find.byType(PlayerBadge), matching: find.byType(Container)));
    expect((box.decoration! as BoxDecoration).color, const Color(0xFFEF4444));
  });

  test('colours repeat after four players', () {
    expect(PlayerBadge.colorOf(4), PlayerBadge.colorOf(0));
  });
}
