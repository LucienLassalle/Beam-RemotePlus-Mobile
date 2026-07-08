import 'package:flutter/material.dart';

import '../localization/app_strings.dart';

/// Paire de boutons pour changer de véhicule actif dans BeamNG.drive.
/// Nécessite le mod Beam-RemotePlus actif côté jeu (commandes textuelles).
/// [enabled] doit être true uniquement quand le mod est détecté.
class VehicleSwitchButtons extends StatelessWidget {
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final bool enabled;

  const VehicleSwitchButtons({
    super.key,
    required this.onPrev,
    required this.onNext,
    this.enabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _VehicleButton(
          icon: Icons.skip_previous,
          tooltip: Strings.t('vehicle_prev'),
          onTap: enabled ? onPrev : null,
        ),
        const SizedBox(width: 4),
        _VehicleButton(
          icon: Icons.skip_next,
          tooltip: Strings.t('vehicle_next'),
          onTap: enabled ? onNext : null,
        ),
      ],
    );
  }
}

class _VehicleButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _VehicleButton({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              icon,
              color: active ? Colors.white70 : Colors.white24,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
