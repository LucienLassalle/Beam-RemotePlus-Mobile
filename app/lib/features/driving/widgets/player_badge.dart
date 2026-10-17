import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';

/// "P1", "P2"... in the colour the game gives the player (its name tag above
/// the car in local multiplayer, also shown by the mod's in-game panel):
/// everyone knows which car is theirs.
class PlayerBadge extends StatelessWidget {
  /// 0-based BeamNG player.
  final int player;

  /// 0xRRGGBB, as the mod reports it.
  final int color;
  const PlayerBadge({super.key, required this.player, required this.color});

  @override
  Widget build(BuildContext context) {
    final background = Color(0xFF000000 | color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(8)),
      child: Text(
        AppLocalizations.of(context).playerBadge(player + 1),
        style: TextStyle(
          // Readable on any colour (the game also has white and yellow).
          color: background.computeLuminance() > 0.4 ? Colors.black : Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
