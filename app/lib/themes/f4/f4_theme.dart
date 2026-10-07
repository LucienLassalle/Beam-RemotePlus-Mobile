import 'package:flutter/material.dart';

import '../kit/kit.dart';

/// F4: single-seater steering wheel display (Carbonworks F4 style): shift
/// LEDs on top, huge gear in the middle, speed/RPM on the left, temperatures
/// and fuel on the right, driver aids at the bottom. The gear cell turns blue
/// at the shift point, like race displays do.
class F4Theme extends ControlTheme {
  const F4Theme();

  @override
  String get name => 'F4';

  @override
  String get author => 'LucienLassalle';

  @override
  ThemeStyle get style => const ThemeStyle(brakeColor: Color(0xFFFF3D00), throttleColor: Color(0xFF00E676));

  static const _panel = Color(0xFF111317);
  static const _cell = Color(0xFF050608);
  static const _border = Color(0x33FFFFFF);

  @override
  Widget buildDashboard(BuildContext context, DashboardData data) {
    final t = data.telemetry;
    final shift = t.shiftLight ?? false;
    return Center(
      child: FittedBox(
        child: Container(
          width: 640,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: BoxDecoration(
            color: _panel,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: _border, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShiftLights(rpm: t.rpm, maxRpm: t.maxRpm, shiftNow: shift, count: 15, size: 22, startRatio: 0.55),
              const SizedBox(height: 10),
              _RpmBar(ratio: t.rpmRatio, shift: shift),
              const SizedBox(height: 10),
              SizedBox(
                height: 200,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Column(children: [
                        ValueBox(label: data.useKmh ? 'KM/H' : 'MPH', value: DashFormat.speed(t, kmh: data.useKmh), valueSize: 30),
                        ValueBox(label: 'RPM', value: DashFormat.integer(t.rpm), valueSize: 30),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        decoration: BoxDecoration(
                          color: shift ? Colors.lightBlueAccent : _cell,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _border),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          child: Text(
                            t.gearLabel,
                            style: TextStyle(
                              fontSize: 150,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              color: shift ? Colors.black : (data.gearFlash == null ? Colors.white : Colors.amberAccent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Column(children: [
                        ValueBox(
                          label: 'WATER',
                          value: DashFormat.integer(t.waterTemp),
                          valueSize: 22,
                          valueColor: (t.waterTemp ?? 0) > 115 ? Colors.redAccent : Colors.white,
                        ),
                        ValueBox(
                          label: 'OIL',
                          value: DashFormat.integer(t.oilTemp),
                          valueSize: 22,
                          valueColor: t.lowPressure == true ? Colors.redAccent : Colors.white,
                        ),
                        ValueBox(
                          label: 'FUEL %',
                          value: DashFormat.fuelPercent(t),
                          valueSize: 22,
                          valueColor: t.lowFuel == true ? Colors.orangeAccent : Colors.white,
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              _AidsRow(t: t),
            ],
          ),
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final List<Widget> children;
  const _Column({required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Expanded(child: children[i]),
          ],
        ],
      );
}

class _RpmBar extends StatelessWidget {
  final double? ratio;
  final bool shift;
  const _RpmBar({required this.ratio, required this.shift});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: ratio ?? 0,
          minHeight: 10,
          backgroundColor: Colors.white10,
          color: shift ? Colors.lightBlueAccent : ((ratio ?? 0) > 0.85 ? Colors.redAccent : Colors.greenAccent),
        ),
      );
}

class _AidsRow extends StatelessWidget {
  final Telemetry t;
  const _AidsRow({required this.t});

  Widget _flag(String text, bool? on, Color color) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: on == true ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: on == null ? Colors.white10 : color.withValues(alpha: 0.6)),
          ),
          alignment: Alignment.center,
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: on == true ? Colors.black : (on == null ? Colors.white10 : color))),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        _flag('ABS', t.hasAbs == false ? null : t.absActive, Colors.amberAccent),
        _flag('TC', t.hasTcs == false ? null : t.tcsActive, Colors.amberAccent),
        _flag('CRUISE', t.cruiseActive, Colors.lightBlueAccent),
        _flag('LIGHT', t.lowBeam == null && t.highBeam == null ? null : (t.lowBeam ?? false) || (t.highBeam ?? false), Colors.greenAccent),
        _flag('BRAKE', t.parkingBrake, Colors.redAccent),
        _flag('ENG', t.checkEngine, Colors.redAccent),
      ]);
}
