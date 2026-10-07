import 'package:flutter/material.dart';

import '../kit/kit.dart';
import 'civetta_painter.dart';

/// Civetta: recreation of the Civetta Scintilla instrument screen (round
/// segmented tachometer, red wings, gear and speed on top, side bar gauges).
/// Everything is laid out in the in-game 1024x512 design space and scaled.
class CivettaTheme extends ControlTheme {
  const CivettaTheme();

  @override
  String get name => 'Civetta';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(brakeColor: CivettaPainter.red, throttleColor: Color(0xFF3D5AFE));

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    final t = data.telemetry;
    return Center(
      child: FittedBox(
        child: SizedBox(
          width: CivettaPainter.design.width,
          height: CivettaPainter.design.height,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: CivettaPainter(rpm: t.rpm, maxRpm: t.maxRpm, shiftLight: t.shiftLight ?? false),
                ),
              ),
              ..._header(t, data),
              ..._lamps(t),
              ..._insideDial(t, data),
              ..._wing(left: true, t: t),
              ..._wing(left: false, t: t),
            ],
          ),
        ),
      ),
    );
  }

  static const _yellow = CivettaPainter.yellow;
  static const _dim = Color(0xFF8A8A8A);

  Widget _centered(double y, double height, Widget child) =>
      Positioned(left: 312, width: 400, top: y, height: height, child: Center(child: child));

  List<Widget> _header(Telemetry t, DashboardData data) => [
        _centered(4, 16, const Text('GEAR', style: TextStyle(color: _yellow, fontSize: 14, fontWeight: FontWeight.bold))),
        _centered(
          18,
          62,
          Text(t.gearLabel,
              style: TextStyle(
                  color: data.gearFlash == null ? Colors.white : _yellow, fontSize: 58, fontWeight: FontWeight.w600, height: 1)),
        ),
        _centered(
          78,
          62,
          Text(DashFormat.speed(t, kmh: data.useKmh),
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w600, height: 1)),
        ),
        _centered(138, 16,
            Text(data.useKmh ? 'KMH' : 'MPH', style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold))),
      ];

  Widget _at(double x, double y, Widget child) => Positioned(left: x, top: y, child: child);

  List<Widget> _lamps(Telemetry t) => [
        _at(250, 112, Text(t.driveMode?.toUpperCase() ?? 'MODE', style: const TextStyle(color: Colors.white, fontSize: 14))),
        _at(212, 140, WarningLamp(icon: Icons.light_mode, on: t.lowBeam == true || t.highBeam == true, color: Colors.greenAccent, size: 24)),
        _at(262, 138, WarningLamp(icon: Icons.battery_alert, on: t.engineRunning == null ? null : !t.engineRunning!, color: CivettaPainter.red, size: 26)),
        _at(318, 136, WarningLamp(icon: Icons.tire_repair, on: t.tirePressures == null ? null : t.lowTirePressure(), color: Colors.orange, size: 28)),
        _at(660, 136, WarningLamp(icon: Icons.car_repair, on: t.checkEngine, color: CivettaPainter.red, size: 28)),
        _at(718, 138, WarningLamp(icon: Icons.local_gas_station, on: t.lowFuel, color: Colors.orange, size: 26)),
        _at(768, 136, WarningLamp(icon: Icons.local_parking, on: t.parkingBrake, color: CivettaPainter.red, size: 28)),
        _at(310, 182, WarningLamp(icon: Icons.arrow_back, on: _blink(t.signalLeft, t.hazard), color: Colors.greenAccent, size: 34)),
        _at(682, 182, WarningLamp(icon: Icons.arrow_forward, on: _blink(t.signalRight, t.hazard), color: Colors.greenAccent, size: 34)),
      ];

  static bool? _blink(bool? signal, bool? hazard) => signal == null && hazard == null ? null : (signal ?? false) || (hazard ?? false);

  List<Widget> _insideDial(Telemetry t, DashboardData data) => [
        _centered(
          240,
          30,
          const Text('Civetta', style: TextStyle(color: Colors.white, fontSize: 26, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
        ),
        _at(552, 280, _assistText('ESC', active: t.escOn, known: t.hasEsc ?? t.escActive != null)),
        _at(552, 360, _assistText('TCS', active: t.tcsOn, known: t.hasTcs ?? t.tcsActive != null)),
        _at(430, 280, _assistText('ABS', active: t.absOn, known: t.hasAbs ?? t.absActive != null)),
        _centered(
          440,
          20,
          Text('${DashFormat.distance(t.odometer, kmh: data.useKmh)} ${data.useKmh ? 'km' : 'mi'}',
              style: const TextStyle(color: _dim, fontSize: 16)),
        ),
      ];

  Widget _assistText(String label, {required bool active, required bool known}) => Text(
        label,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: !known ? Colors.transparent : (active ? Colors.orangeAccent : _dim),
        ),
      );

  List<Widget> _wing({required bool left, required Telemetry t}) {
    final x = left ? 150.0 : 694.0;
    Widget row(String label, double? value, int segments, {Color? first, Color? last}) => SizedBox(
          width: 220,
          child: Row(children: [
            SizedBox(width: 62, child: Text(label, style: const TextStyle(color: _dim, fontSize: 13))),
            Expanded(child: SegmentBar(value: value, segments: segments, thickness: 14, firstColor: first, lastColor: last)),
          ]),
        );
    if (left) {
      return [
        _at(x, 270, row('OIL', _range(t.oilTemp, 60, 130), 4, last: CivettaPainter.red)),
        _at(x, 300, row('WATER', _range(t.waterTemp, 60, 120), 6, first: Colors.blueAccent, last: CivettaPainter.red)),
        _at(x + 40, 340, Text(DashFormat.clock(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 22))),
      ];
    }
    return [
      _at(x, 270, row('BOOST', _range(t.boost, 0, 6), 4, last: CivettaPainter.red)),
      _at(x, 300, row('FUEL', t.fuel, 6, first: CivettaPainter.red)),
      _at(x + 70, 340, Text('${DashFormat.integer(t.envTemp)}°C', style: const TextStyle(color: Colors.white, fontSize: 22))),
    ];
  }

  static double? _range(double? v, double min, double max) => v == null ? null : ((v - min) / (max - min)).clamp(0.0, 1.0);
}
