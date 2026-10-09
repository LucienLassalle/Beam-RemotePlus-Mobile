import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../kit/kit.dart';

/// Road: everyday driving. Speed, gear, fuel and temperatures, the usual
/// warning lights, and every vehicle button (indicators, hazards, lights,
/// horn, parking brake, ignition, drive mode, cruise control); each button
/// can be hidden in the settings.
class RoadTheme extends ControlTheme {
  const RoadTheme();

  @override
  String get name => 'Road';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(actions: {...VehicleAction.values});

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    final t = data.telemetry;
    final l10n = AppLocalizations.of(context);
    if (!data.modActive) return const SizedBox.shrink();
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              WarningLamp(icon: Icons.arrow_back, on: (t.signalLeft ?? false) || (t.hazard ?? false), color: Colors.greenAccent, size: 34),
              const SizedBox(width: 40),
              WarningLamp(icon: Icons.light_mode, on: t.lowBeam, color: Colors.greenAccent, size: 26),
              WarningLamp(icon: Icons.highlight, on: t.highBeam, color: Colors.lightBlueAccent, size: 26),
              WarningLamp(icon: Icons.speed, on: t.cruiseActive, color: Colors.greenAccent, size: 26),
              WarningLamp(icon: Icons.local_parking, on: t.parkingBrake, color: Colors.redAccent, size: 26),
              const SizedBox(width: 40),
              WarningLamp(icon: Icons.arrow_forward, on: (t.signalRight ?? false) || (t.hazard ?? false), color: Colors.greenAccent, size: 34),
            ]),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(DashFormat.speed(t, kmh: data.useKmh),
                  style: const TextStyle(color: Colors.white, fontSize: 110, fontWeight: FontWeight.w300, height: 1)),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 16),
                child: Text(DashFormat.speedUnit(kmh: data.useKmh), style: const TextStyle(color: Colors.white60, fontSize: 22)),
              ),
            ]),
            if (t.cruiseActive == true && t.cruiseSpeed != null)
              Text('⟲ ${DashFormat.integer(t.cruiseSpeed! * (data.useKmh ? 3.6 : 2.23694))}',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 18)),
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              _Info(label: t.driveMode ?? '', value: t.gearLabel, big: true),
              _Info(label: t.isElectric ? l10n.dashBattery : l10n.dashFuel, value: '${DashFormat.fuelPercent(t)}%'),
              if (t.isElectric)
                _Info(label: l10n.dashPower, value: '${DashFormat.integer(t.motorPower)} kW')
              else
                _Info(label: l10n.dashCoolant, value: '${DashFormat.temperature(t.waterTemp, data.temperatureUnit)}°'),
              _Info(label: data.useKmh ? 'KM' : 'MI', value: DashFormat.distance(t.odometer, kmh: data.useKmh)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  const _Info({required this.label, required this.value, this.big = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2)),
          Text(value, style: TextStyle(color: big ? Colors.amberAccent : Colors.white70, fontSize: big ? 30 : 20, fontWeight: FontWeight.w600)),
        ]),
      );
}
