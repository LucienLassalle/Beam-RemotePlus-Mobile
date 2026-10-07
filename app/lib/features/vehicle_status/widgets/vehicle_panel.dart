import 'package:flutter/material.dart';

import '../../../core/protocol/telemetry.dart';
import '../../../themes/kit/damage_view.dart';
import '../../../themes/kit/radar_view.dart';

/// Radar + damage/tyres panel, shown on demand over the driving screen and
/// permanently in second-screen mode. Never takes touches.
class VehiclePanel extends StatelessWidget {
  final Telemetry telemetry;
  final double height;

  const VehiclePanel({super.key, required this.telemetry, this.height = 150});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          height: height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            RadarView(targets: telemetry.radar),
            const SizedBox(width: 12),
            DamageView(telemetry: telemetry),
          ]),
        ),
      );
}
