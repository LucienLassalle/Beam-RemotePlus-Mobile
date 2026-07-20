import 'package:flutter/material.dart';

import '../protocol/mod_packets.dart';
import 'control_theme.dart';

/// Thème "F4" : panneau arrondi façon volant de monoplace, rangée de LEDs
/// de rupteur en haut, rapport engagé au centre en grand.
class F4Theme implements ControlTheme {
  @override
  String get id => 'f4';

  @override
  String get displayName => 'F4';

  static const _panelBg = Color(0xFF16181C);
  static const _innerBg = Color(0xFF0C0D10);
  static const _border = Color(0x33FFFFFF);
  static const _text = Colors.white;
  static const _dim = Colors.white38;

  @override
  Widget build(BuildContext context, ControlSurface surface) {
    return Stack(
      children: [
        // ── Tableau de bord : arrière-plan du thème ──────────────────────
        Center(
          child: surface.modActive
              ? _Dash(
                  telemetry: surface.telemetry,
                  useKmh: surface.useKmh,
                  width: MediaQuery.of(context).size.width * 0.68,
                )
              : const Icon(Icons.info_outline, color: Colors.white24, size: 28),
        ),

        // ── Pédales : contrôle, posé par-dessus le tableau de bord ───────
        Positioned.fill(child: surface.pedalsWidgetInvisible),

        Positioned(
          bottom: 20,
          left: MediaQuery.of(context).size.width * 0.33,
          right: MediaQuery.of(context).size.width * 0.33,
          child: surface.steeringWidget,
        ),

        Positioned(
          bottom: 8,
          left: 0,
          right: 0,
          child: Center(child: surface.cameraButtonsWidget),
        ),

        if (surface.gearFlashColor != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                color: surface.gearFlashColor!.withValues(alpha: 0.22),
              ),
            ),
          ),

        Positioned(top: 4, left: 4, child: surface.vehicleSwitchWidget),
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

class _Dash extends StatelessWidget {
  final Stream<ModTelemetryPacket> telemetry;
  final bool useKmh;
  final double width;

  const _Dash({
    required this.telemetry,
    required this.useKmh,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    // Échelle relative à la largeur de référence du design d'origine (300).
    final s = (width / 300).clamp(1.0, 2.4);

    return StreamBuilder<ModTelemetryPacket>(
      stream: telemetry,
      builder: (context, snapshot) {
        final t = snapshot.data;
        final speed =
            (t == null ? 0 : (useKmh ? t.speedKmh : t.speedMph)).round();
        final rpm = t?.rpm ?? 0;
        final redline = t?.redlineRpm ?? 7000;

        return Container(
          width: width,
          padding: EdgeInsets.fromLTRB(16 * s, 10 * s, 16 * s, 14 * s),
          decoration: BoxDecoration(
            color: F4Theme._panelBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: F4Theme._border, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShiftLights(rpm: rpm, redline: redline, scale: s),
              SizedBox(height: 10 * s),
              Container(
                padding: EdgeInsets.all(10 * s),
                decoration: BoxDecoration(
                  color: F4Theme._innerBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Box(
                      label: 'RPM',
                      value: rpm.round().toString(),
                      valueFontSize: 22 * s,
                      scale: s,
                    ),
                    SizedBox(height: 6 * s),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                _Box(
                                  label: 'FUEL',
                                  value:
                                      (t?.fuel ?? 0).toStringAsFixed(1),
                                  valueFontSize: 18 * s,
                                  scale: s,
                                ),
                                SizedBox(height: 6 * s),
                                _Box(
                                  label: 'OIL T',
                                  value: (t?.oilTemp ?? 0) > 0
                                      ? (t!.oilTemp).round().toString()
                                      : '–',
                                  valueFontSize: 18 * s,
                                  scale: s,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          Expanded(
                            child: _Box(
                              label: 'GEAR',
                              value: t?.gearLabel ?? 'N',
                              valueFontSize: 40 * s,
                              scale: s,
                              expand: true,
                            ),
                          ),
                          SizedBox(width: 6 * s),
                          Expanded(
                            child: Column(
                              children: [
                                _Box(
                                  label: 'KM/H',
                                  value: speed.toString(),
                                  valueFontSize: 18 * s,
                                  scale: s,
                                ),
                                SizedBox(height: 6 * s),
                                _Box(
                                  label: 'WAT T',
                                  value: (t?.engineTemp ?? 0)
                                      .round()
                                      .toString(),
                                  valueFontSize: 18 * s,
                                  scale: s,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Rangée de LEDs rondes de rupteur, façon volant de monoplace : s'allument
/// progressivement du centre vers l'extérieur à l'approche du régime max.
class _ShiftLights extends StatelessWidget {
  final double rpm;
  final double redline;
  final double scale;
  static const int count = 10;

  const _ShiftLights({
    required this.rpm,
    required this.redline,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    final rangeStart = redline * 0.6;
    final ratio = redline > rangeStart
        ? ((rpm - rangeStart) / (redline - rangeStart)).clamp(0.0, 1.0)
        : 0.0;
    final litCount = (ratio * count).round();
    final dotSize = 12 * scale;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final lit = i < litCount;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 2 * scale),
          child: Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lit ? Colors.redAccent : Colors.white10,
              boxShadow: lit
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.7),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}

class _Box extends StatelessWidget {
  final String label;
  final String value;
  final double valueFontSize;
  final bool expand;
  final double scale;

  const _Box({
    required this.label,
    required this.value,
    this.valueFontSize = 18,
    this.expand = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: expand ? double.infinity : null,
      padding: EdgeInsets.symmetric(vertical: 6 * scale),
      decoration: BoxDecoration(
        border: Border.all(color: F4Theme._border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9 * scale,
              color: F4Theme._dim,
              letterSpacing: 1.5,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
              color: F4Theme._text,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
