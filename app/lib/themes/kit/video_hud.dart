import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../control_theme.dart';
import 'dash_format.dart';

/// Light dashboard over the point of view video (the default of
/// [ControlTheme.buildVideoDashboard]): the engine on the right (RPM, gear,
/// speed), the gauges on the left (oil, water, fuel), on a faint background
/// so the road stays visible behind. Values the vehicle does not send are
/// left out.
class VideoHud extends StatelessWidget {
  final DashboardData data;

  const VideoHud({super.key, required this.data});

  static const Color background = Color(0x4D000000);
  static const Color alert = Color(0xFFFF5252);

  @override
  Widget build(BuildContext context) {
    if (!data.modActive) return const SizedBox.shrink();
    final t = data.telemetry;
    final l10n = AppLocalizations.of(context);
    final unit = data.temperatureUnit;
    String temperature(double? c) => '${DashFormat.temperature(c, unit)}${unit.symbol}';
    final gauges = [
      if (t.oilTemp != null) _Value(label: l10n.dashOil, value: temperature(t.oilTemp), alert: t.oilTemp! >= 120),
      if (t.waterTemp != null) _Value(label: l10n.dashWater, value: temperature(t.waterTemp), alert: t.waterTemp! >= 120),
      if (t.fuel != null)
        _Value(label: t.isElectric ? l10n.dashBattery : l10n.dashFuel, value: '${DashFormat.fuelPercent(t)}%', alert: t.lowFuel ?? false),
    ];
    final engine = [
      if (t.isElectric && t.motorPower != null)
        _Value(label: l10n.dashPower, value: '${DashFormat.integer(t.motorPower)} kW')
      else if (t.rpm != null)
        _Value(label: 'RPM', value: DashFormat.integer(t.rpm), alert: t.shiftLight ?? false),
      _Value(label: '', value: t.gearLabel, size: 40, alert: data.gearFlash != null),
      _Value(label: DashFormat.speedUnit(kmh: data.useKmh), value: DashFormat.speed(t, kmh: data.useKmh), size: 30),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        if (gauges.isNotEmpty) _Panel(children: gauges),
        const Spacer(),
        _Panel(children: engine),
      ]),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<Widget> children;

  const _Panel({required this.children});

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: VideoHud.background, borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}

class _Value extends StatelessWidget {
  final String label;
  final String value;
  final double size;
  final bool alert;

  const _Value({required this.label, required this.value, this.size = 20, this.alert = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (label.isNotEmpty)
            Text(label.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
          Text(
            value,
            style: TextStyle(
              color: alert ? VideoHud.alert : Colors.white,
              fontSize: size,
              fontWeight: FontWeight.w700,
              height: 1.1,
              shadows: const [Shadow(blurRadius: 3)],
            ),
          ),
        ]),
      );
}
