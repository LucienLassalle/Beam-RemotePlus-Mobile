import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../protocol/beamng_client.dart';
import '../protocol/mod_packets.dart';
import '../widgets/rpm_led_bar.dart';
import 'control_theme.dart';

/// Thème par défaut : reproduit l'écran de pilotage historique de l'app
/// (tableau de bord central, volant en bas, pédales plein écran, boutons
/// caméra/véhicule/reset dans les coins).
class DefaultTheme implements ControlTheme {
  @override
  String get id => 'default';

  @override
  String get displayName => 'Défaut';

  @override
  Widget build(BuildContext context, ControlSurface surface) {
    return Stack(
      children: [
        // ── Tableau de bord centré : arrière-plan du thème, toujours
        // sous les contrôles ci-dessous. ────────────────────────────────
        Center(
          child: surface.modActive
              ? _FullDashboard(
                  telemetry: surface.telemetry,
                  useKmh: surface.useKmh,
                )
              : const _MinimalDashboard(),
        ),

        // ── Pédales frein / accélérateur, plein écran : contrôle, posé
        // par-dessus le tableau de bord. ────────────────────────────────
        Positioned.fill(child: surface.pedalsWidget),

        // ── Volant : bande basse, centrée. Invisible en mode inclinaison
        // (le widget se masque lui-même), barre de glissement en mode
        // tactile. ──────────────────────────────────────────────────────
        Positioned(
          bottom: 20,
          left: MediaQuery.of(context).size.width * 0.33,
          right: MediaQuery.of(context).size.width * 0.33,
          child: surface.steeringWidget,
        ),

        // ── Boutons caméra (centre, bas) ────────────────────────────────
        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(child: surface.cameraButtonsWidget),
        ),

        // ── Flash visuel changement de rapport ──────────────────────────
        if (surface.gearFlashColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: surface.gearFlashColor!.withValues(alpha: 0.22),
              ),
            ),
          ),

        // ── Statut de connexion (réservé : ne pas empiéter sur le coin
        // haut-droit, occupé par les boutons Paramètres/Aide de l'hôte) ──
        Positioned(
          top: 8,
          right: 90,
          child: _StatusChip(
            connectionState: surface.connectionState,
            latency: surface.latency,
          ),
        ),

        // ── Changement de véhicule (haut gauche) ────────────────────────
        Positioned(top: 4, left: 4, child: surface.vehicleSwitchWidget),

        // ── Reset véhicule (haut centre) ────────────────────────────────
        Positioned(
          top: 4,
          left: 0,
          right: 0,
          child: Center(child: surface.resetVehicleWidget),
        ),
      ],
    );
  }
}

class _FullDashboard extends StatelessWidget {
  final Stream<ModTelemetryPacket> telemetry;
  final bool useKmh;

  const _FullDashboard({required this.telemetry, required this.useKmh});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ModTelemetryPacket>(
      stream: telemetry,
      builder: (context, snapshot) {
        final t = snapshot.data;
        final speed =
            t == null ? 0 : (useKmh ? t.speedKmh : t.speedMph).round();
        final unit = useKmh ? 'km/h' : 'mph';

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            RpmLedBar(rpm: t?.rpm ?? 0, redlineRpm: t?.redlineRpm ?? 7000),
            const SizedBox(height: 4),
            Text(
              '${(t?.rpm ?? 0).round()} RPM',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$speed',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 88,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 18, left: 6),
                  child: Text(
                    unit,
                    style: const TextStyle(color: Colors.white70, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 28),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    t?.gearLabel ?? '-',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniGauge(
                  label: Strings.t('gauge_fuel'),
                  value: (t?.fuel ?? 0) * 100,
                  max: 100,
                ),
                const SizedBox(width: 16),
                _MiniGauge(
                  label: Strings.t('gauge_temp'),
                  value: t?.engineTemp ?? 0,
                  max: 120,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MinimalDashboard extends StatelessWidget {
  const _MinimalDashboard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, color: Colors.white24, size: 28),
          const SizedBox(height: 8),
          Text(
            Strings.t('mod_banner'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final BeamngConnectionState connectionState;
  final Duration? latency;

  const _StatusChip({required this.connectionState, required this.latency});

  @override
  Widget build(BuildContext context) {
    final label = switch (connectionState) {
      BeamngConnectionState.connected => latency != null
          ? '${latency!.inMilliseconds}ms'
          : Strings.t('status_connected'),
      BeamngConnectionState.discovering => Strings.t('status_connecting'),
      BeamngConnectionState.timeout => Strings.t('status_timeout'),
      BeamngConnectionState.error => Strings.t('status_error'),
      BeamngConnectionState.idle => Strings.t('status_idle'),
    };
    final color = connectionState == BeamngConnectionState.connected
        ? Colors.greenAccent
        : Colors.redAccent;
    return Text(label, style: TextStyle(color: color, fontSize: 12));
  }
}

class _MiniGauge extends StatelessWidget {
  final String label;
  final double value;
  final double max;

  const _MiniGauge({
    required this.label,
    required this.value,
    required this.max,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return SizedBox(
      width: 120,
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: Colors.white12,
                color: ratio > 0.85 ? Colors.redAccent : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
