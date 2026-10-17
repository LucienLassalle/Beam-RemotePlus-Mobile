import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// "P1", "P2"... in the colour of the player, the same as the mod's in-game
/// panel shows: in local multiplayer, everyone knows which car is theirs.
class PlayerBadge extends StatelessWidget {
  /// 0-based BeamNG player.
  final int player;
  const PlayerBadge({super.key, required this.player});

  /// Player 1 blue, 2 red, 3 green, 4 yellow (as in the mod's app.vue).
  static const List<Color> colors = [Color(0xFF3B82F6), Color(0xFFEF4444), Color(0xFF22C55E), Color(0xFFEAB308)];

  static Color colorOf(int player) => colors[player % colors.length];

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: colorOf(player), borderRadius: BorderRadius.circular(8)),
        child: Text(
          AppLocalizations.of(context).playerBadge(player + 1),
          style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
        ),
      );
}
