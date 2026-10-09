import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// Clean general-purpose dashboard: big speed, RPM LEDs, gear, fuel,
/// temperatures and the main warning lights.
class DefaultTheme extends ControlTheme {
  const DefaultTheme();

  @override
  String get name => 'Default';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(visiblePedals: true);

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    if (!data.modActive) {
      return const Center(child: Icon(Icons.speed, size: 72, color: Colors.white12));
    }
    final t = data.telemetry;
    return Center(
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShiftLights(rpm: t.rpm, maxRpm: t.maxRpm, shiftNow: t.shiftLight ?? false, count: 12, size: 14),
              const SizedBox(height: 6),
              if (t.isElectric)
                // Motor power, green while the regenerative braking charges.
                Text('${DashFormat.integer(t.motorPower)} kW',
                    style: TextStyle(color: (t.motorPower ?? 0) < 0 ? Colors.greenAccent : Colors.white54, fontSize: 13))
              else
                Text('${DashFormat.integer(t.rpm)} RPM', style: const TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DashFormat.speed(t, kmh: data.useKmh),
                    style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.bold, height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 6, bottom: 14),
                    child: Text(DashFormat.speedUnit(kmh: data.useKmh),
                        style: const TextStyle(color: Colors.white70, fontSize: 20)),
                  ),
                  const SizedBox(width: 32),
                  Text(
                    t.gearLabel,
                    style: TextStyle(
                      color: data.gearFlash == null ? Colors.amberAccent : Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Gauge(
                    icon: t.isElectric ? Icons.battery_charging_full : Icons.local_gas_station,
                    value: '${DashFormat.fuelPercent(t)}%',
                    warn: t.lowFuel ?? false,
                  ),
                  if (!t.isElectric) ...[
                    _Gauge(
                      icon: Icons.thermostat,
                      value: '${DashFormat.temperature(t.waterTemp, data.temperatureUnit)}°',
                      warn: (t.waterTemp ?? 0) > 115,
                    ),
                    _Gauge(
                      icon: Icons.oil_barrel,
                      value: '${DashFormat.temperature(t.oilTemp, data.temperatureUnit)}°',
                      warn: t.lowPressure ?? false,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  WarningLamp(icon: Icons.arrow_back, on: t.signalLeft, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  WarningLamp(icon: Icons.highlight, on: t.highBeam, color: Colors.lightBlueAccent),
                  WarningLamp(icon: Icons.light_mode, on: t.lowBeam, color: Colors.greenAccent),
                  WarningLamp(icon: Icons.local_parking, on: t.parkingBrake, color: Colors.redAccent),
                  WarningLamp(icon: Icons.warning_amber, on: t.hazard, color: Colors.redAccent),
                  _TextLamp('ABS', on: t.absOn),
                  _TextLamp('TCS', on: t.tcsOn),
                  WarningLamp(icon: Icons.speed, on: t.cruiseActive, color: Colors.greenAccent),
                  const SizedBox(width: 12),
                  WarningLamp(icon: Icons.arrow_forward, on: t.signalRight, color: Colors.greenAccent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  final IconData icon;
  final String value;
  final bool warn;
  const _Gauge({required this.icon, required this.value, required this.warn});

  @override
  Widget build(BuildContext context) {
    final color = warn ? Colors.orangeAccent : Colors.white70;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18)),
      ]),
    );
  }
}

class _TextLamp extends StatelessWidget {
  final String text;
  final bool on;
  const _TextLamp(this.text, {required this.on});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: on ? Colors.orangeAccent : Colors.white.withValues(alpha: 0.15))),
      );
}
