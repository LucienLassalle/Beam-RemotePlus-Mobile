import 'package:flutter/material.dart';

import '../../core/debug/debug_monitor.dart';
import '../../core/network/remote_link.dart';
import '../../l10n/generated/app_localizations.dart';

/// Debug panel shown over the driving screen when the debug mode is on:
/// mod/protocol, telemetry rate, values the vehicle did not send
/// ("oilTemp returned nothing.") and the last command results
/// ("horn|1 impossible: no_vehicle").
class DebugOverlay extends StatelessWidget {
  final DebugMonitor monitor;
  final RemoteLink link;

  const DebugOverlay({super.key, required this.monitor, required this.link});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: monitor,
      builder: (context, _) {
        final lines = <(String, Color)>[];
        if (!link.modActive) {
          lines.add((l10n.debugNoMod, Colors.orangeAccent));
        } else {
          lines.add((l10n.debugProtocol(monitor.modVersion ?? '?', link.protocolVersion), Colors.white70));
          final rate = monitor.telemetryRate;
          lines.add(rate == 0 ? (l10n.debugNoTelemetry, Colors.redAccent) : (l10n.debugTelemetryRate(rate), Colors.white70));
          if (monitor.lastTelemetry != null) {
            final missing = monitor.missingFields;
            if (missing.isEmpty) {
              lines.add((l10n.debugAllValues, Colors.greenAccent));
            } else {
              lines.addAll(missing.map((f) => (l10n.debugNoValue(f), Colors.amberAccent)));
            }
          }
          for (final r in monitor.journal) {
            lines.add(r.ok
                ? (l10n.debugCommandOk(r.command), Colors.greenAccent)
                : (l10n.debugCommandFailed(r.command, r.error ?? '?'), Colors.redAccent));
          }
        }
        return Container(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 260),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(6)),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.debugTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                for (final (text, color) in lines) Text(text, style: TextStyle(color: color, fontSize: 11, fontFamily: 'monospace')),
              ],
            ),
          ),
        );
      },
    );
  }
}
