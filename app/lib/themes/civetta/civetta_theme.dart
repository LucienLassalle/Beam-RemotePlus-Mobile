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
              ..._wing(left: true, t: t, unit: data.temperatureUnit),
              ..._wing(left: false, t: t, unit: data.temperatureUnit),
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
        _centered(6, 14, const Text('GEAR', style: TextStyle(color: _yellow, fontSize: 12, fontWeight: FontWeight.bold))),
        _centered(
          20,
          44,
          Text(t.gearLabel,
              style: TextStyle(
                  color: data.gearFlash == null ? Colors.white : _yellow, fontSize: 42, fontWeight: FontWeight.w600, height: 1)),
        ),
        _centered(
          66,
          48,
          Text(DashFormat.speed(t, kmh: data.useKmh),
              style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w600, height: 1)),
        ),
        _centered(116, 14,
            Text(data.useKmh ? 'KMH' : 'MPH', style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold))),
      ];

  Widget _at(double x, double y, Widget child) => Positioned(left: x, top: y, child: child);

  List<Widget> _lamps(Telemetry t) => [
        _at(240, 114, Text(t.driveMode?.toUpperCase() ?? 'MODE', style: const TextStyle(color: Colors.white, fontSize: 13))),
        _at(206, 138, WarningLamp(icon: Icons.light_mode, on: t.lowBeam == true || t.highBeam == true, color: Colors.greenAccent, size: 22)),
        _at(250, 138, WarningLamp(icon: Icons.battery_alert, on: t.engineRunning == null ? null : !t.engineRunning!, color: CivettaPainter.red, size: 22)),
        _at(294, 138, WarningLamp(icon: Icons.tire_repair, on: t.tirePressures == null ? null : t.lowTirePressure(), color: Colors.orange, size: 22)),
        _at(708, 138, WarningLamp(icon: Icons.car_repair, on: t.checkEngine, color: CivettaPainter.red, size: 22)),
        _at(752, 138, WarningLamp(icon: Icons.local_gas_station, on: t.lowFuel, color: Colors.orange, size: 22)),
        _at(796, 138, WarningLamp(icon: Icons.local_parking, on: t.parkingBrake, color: CivettaPainter.red, size: 22)),
        _at(300, 186, WarningLamp(icon: Icons.arrow_back, on: _blink(t.signalLeft, t.hazard), color: Colors.greenAccent, size: 30)),
        _at(694, 186, WarningLamp(icon: Icons.arrow_forward, on: _blink(t.signalRight, t.hazard), color: Colors.greenAccent, size: 30)),
      ];

  static bool? _blink(bool? signal, bool? hazard) => signal == null && hazard == null ? null : (signal ?? false) || (hazard ?? false);

  List<Widget> _insideDial(Telemetry t, DashboardData data) => [
        _centered(
          262,
          26,
          const Text('Civetta', style: TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700)),
        ),
        _centered(
          392,
          20,
          Row(mainAxisSize: MainAxisSize.min, children: [
            _assistText('ABS', active: t.absOn, known: t.hasAbs ?? t.absActive != null),
            const SizedBox(width: 14),
            _assistText('ESC', active: t.escOn, known: t.hasEsc ?? t.escActive != null),
            const SizedBox(width: 14),
            _assistText('TCS', active: t.tcsOn, known: t.hasTcs ?? t.tcsActive != null),
          ]),
        ),
        _centered(
          446,
          18,
          Text('${DashFormat.distance(t.odometer, kmh: data.useKmh)} ${data.useKmh ? 'km' : 'mi'}',
              style: const TextStyle(color: _dim, fontSize: 12)),
        ),
      ];

  Widget _assistText(String label, {required bool active, required bool known}) => Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: !known ? Colors.white10 : (active ? Colors.orangeAccent : _dim),
        ),
      );

  /// Side wings: the usable area is x 150..320 (left) and 704..874 (right),
  /// between the slanted red edge and the dial.
  List<Widget> _wing({required bool left, required Telemetry t, required TemperatureUnit unit}) {
    final x = left ? 150.0 : 704.0;
    Widget row(String label, double? value, int segments, {Color? first, Color? last}) => SizedBox(
          width: 170,
          child: Row(children: [
            SizedBox(width: 50, child: Text(label, style: const TextStyle(color: _dim, fontSize: 11))),
            Expanded(child: SegmentBar(value: value, segments: segments, thickness: 11, firstColor: first, lastColor: last)),
          ]),
        );
    final caption = TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 18);
    if (left) {
      return [
        _at(x + 14, 272, row('OIL', _range(t.oilTemp, 60, 130), 4, last: CivettaPainter.red)),
        _at(x, 300, row('WATER', _range(t.waterTemp, 60, 120), 6, first: Colors.blueAccent, last: CivettaPainter.red)),
        _at(x + 44, 336, Text(DashFormat.clock(DateTime.now()), style: caption)),
      ];
    }
    return [
      _at(x, 272, row('BOOST', _range(t.boost, 0, 6), 4, last: CivettaPainter.red)),
      _at(x, 300, row('FUEL', t.fuel, 6, first: CivettaPainter.red)),
      _at(x + 60, 336, Text('${DashFormat.temperature(t.envTemp, unit)}${unit.symbol}', style: caption)),
    ];
  }

  static double? _range(double? v, double min, double max) => v == null ? null : ((v - min) / (max - min)).clamp(0.0, 1.0);
}
