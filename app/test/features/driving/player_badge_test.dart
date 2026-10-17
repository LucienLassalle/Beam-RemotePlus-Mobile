import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/features/driving/widgets/player_badge.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('shows the player number in the colour the game gives the player', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link);
    link.telemetry_.add(const Telemetry(player: 1));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PlayerBadge), findsNothing, reason: 'no colour from the mod yet: no guess');

    link.events_.add(const SessionMessage(player: 1, playerColor: 0x2673FF));
    await tester.pump();
    await tester.pump();
    expect(find.text('P2'), findsOneWidget);
    final box = tester.widget<Container>(find.descendant(of: find.byType(PlayerBadge), matching: find.byType(Container)));
    expect((box.decoration! as BoxDecoration).color, const Color(0xFF2673FF));
  });

  test('reads the "#rrggbb" colours of the mod', () {
    expect(parseHexColor('#f21a1a'), 0xF21A1A);
    expect(parseHexColor('2673ff'), 0x2673FF);
    expect(parseHexColor('red'), isNull);
    expect(parseHexColor(null), isNull);
  });
}
