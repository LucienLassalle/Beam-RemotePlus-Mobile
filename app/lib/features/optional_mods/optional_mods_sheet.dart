import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'optional_mods.dart';

/// Lists the optional mods the app works with and what each one adds.
/// [states]: state of each mod in the game by id, as the connected mod
/// reports it; null when unknown (not connected, or an older mod): no
/// state shown then.
Future<void> showOptionalModsSheet(BuildContext context, {Map<String, String>? states}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text(l10n.optionalModsTitle, style: Theme.of(context).textTheme.titleMedium)),
            const SizedBox(height: 8),
            Text(states == null ? l10n.optionalModsHintOffline : l10n.optionalModsHint,
                style: const TextStyle(fontSize: 12, color: Colors.white54)),
            const SizedBox(height: 8),
            for (final mod in OptionalMod.values)
              _ModRow(mod: mod, state: states == null ? null : OptionalModState.tryParse(states[mod.id])),
          ]),
        ),
      );
    },
  );
}

class _ModRow extends StatelessWidget {
  final OptionalMod mod;

  /// null: unknown.
  final OptionalModState? state;

  const _ModRow({required this.mod, required this.state});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = this.state;
    return Opacity(
      opacity: state == OptionalModState.missing ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          const Icon(Icons.extension, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(mod.name(l10n), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(mod.features(l10n), style: const TextStyle(fontSize: 12, color: Colors.white54)),
            ]),
          ),
          if (state != null) _StateLabel(state),
        ]),
      ),
    );
  }
}

class _StateLabel extends StatelessWidget {
  final OptionalModState state;
  const _StateLabel(this.state);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (text, color) = switch (state) {
      OptionalModState.enabled => (l10n.optionalModEnabled, Colors.greenAccent),
      OptionalModState.disabled => (l10n.optionalModDisabled, Colors.orangeAccent),
      OptionalModState.missing => (l10n.optionalModMissing, Colors.white38),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (state == OptionalModState.enabled) ...[
        Icon(Icons.check_circle, color: color, size: 16),
        const SizedBox(width: 4),
      ],
      Text(text, style: TextStyle(fontSize: 12, color: color)),
    ]);
  }
}
