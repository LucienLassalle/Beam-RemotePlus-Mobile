import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// F4: recreation of the Carbonworks F4 (fr04, by LucasBE) steering wheel
/// screen: 320x220 display with RPM on top, fuel and speed on the sides,
/// oil and water temperatures below, a big gear in a blue box, and a red
/// blinking banner for "WATER TEMP HI", "OIL TEMP HI" and "FUEL LEVEL LOW".
/// Laid out in the original 320x220 pixel space and scaled to the phone.
class F4Theme extends ControlTheme {
  const F4Theme();

  @override
  String get name => 'F4';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(brakeColor: Color(0xFFFF3D00), throttleColor: Color(0xFF00E676));

  static const Size design = Size(320, 220);
  static const background = Color(0xFF050505);
  static const textColor = Color(0xFFBBBAAE);

  /// Same thresholds as the car's own screen script.
  static String? infoMessage(Telemetry t) {
    if ((t.fuelVolume ?? double.infinity) <= 5) return 'FUEL LEVEL LOW';
    if ((t.oilTemp ?? 0) >= 120) return 'OIL TEMP HI';
    if ((t.waterTemp ?? 0) >= 120) return 'WATER TEMP HI';
    return null;
  }

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    final t = data.telemetry;
    final info = infoMessage(t);
    // Blinks at 1 Hz like the original (redrawn with every telemetry frame).
    final blinkOn = DateTime.now().millisecond < 500;
    return Center(
      child: FittedBox(
        child: Container(
          width: design.width,
          height: design.height,
          color: background,
          child: DefaultTextStyle(
            style: const TextStyle(color: textColor, fontFamily: 'Roboto'),
            child: Stack(children: [
              Positioned(top: 15, left: 113, child: _Field(label: 'RPM', value: DashFormat.integer(t.rpm))),
              Positioned(
                top: 80,
                left: 16,
                child: _Field(
                  label: 'FUEL',
                  value: t.fuelVolume == null ? DashFormat.missing : '${(t.fuelVolume! * 10).floor() / 10} L',
                  alert: (t.fuelVolume ?? double.infinity) <= 5,
                ),
              ),
              Positioned(
                top: 80,
                left: 210,
                child: _Field(label: data.useKmh ? 'KM/H' : 'MPH', value: DashFormat.speed(t, kmh: data.useKmh)),
              ),
              Positioned(
                bottom: 15,
                left: 16,
                child: _Field(label: 'OIL T', value: '${DashFormat.temperature(t.oilTemp, data.temperatureUnit)} ${data.temperatureUnit.symbol.substring(1)}', alert: (t.oilTemp ?? 0) >= 120),
              ),
              Positioned(
                bottom: 15,
                left: 210,
                child: _Field(label: 'WAT T', value: '${DashFormat.temperature(t.waterTemp, data.temperatureUnit)} ${data.temperatureUnit.symbol.substring(1)}', alert: (t.waterTemp ?? 0) >= 120),
              ),
              Positioned(
                bottom: 40,
                left: 113,
                child: _Field(
                  label: 'Gear',
                  value: t.gearLabel,
                  big: true,
                  highlight: data.gearFlash != null || (t.shiftLight ?? false),
                ),
              ),
              if (info != null)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 75,
                  child: ColoredBox(
                    color: Colors.red,
                    child: Center(
                      child: Opacity(
                        opacity: blinkOn ? 1 : 0,
                        child: Text(info, style: const TextStyle(fontSize: 30)),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// HTML <fieldset> look of the original screen: rounded box, dark gradient,
/// legend sitting on the top border.
class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool big;
  final bool alert;
  final bool highlight;

  const _Field({required this.label, required this.value, this.big = false, this.alert = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final top = big ? const Color(0xFF0F2970) : const Color(0xFF12141A);
    return SizedBox(
      width: 94,
      height: big ? 104 : 52,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned.fill(
          top: 7,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: big ? const Color(0xFF0F2970) : const Color(0xFF1C1F29)),
              color: alert ? Colors.red : null,
              gradient: alert
                  ? null
                  : LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [highlight ? Colors.lightBlueAccent : top, F4Theme.background],
                    ),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              child: Text(value, style: TextStyle(fontSize: big ? 80 : 20, height: 1)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              color: F4Theme.background,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text(label, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ),
      ]),
    );
  }
}
