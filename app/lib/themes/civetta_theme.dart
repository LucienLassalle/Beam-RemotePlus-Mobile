import 'package:flutter/material.dart';

import '../protocol/mod_packets.dart';
import 'control_theme.dart';

/// Thème "Civetta" : tableau de bord numérique façon simulateur de course
/// (grille de cadrans rectangulaires, barre de régime segmentée numérotée).
///
/// N'affiche que des données réellement fournies par BeamNG : pas de
/// températures par roue ni de chrono/delta au tour (pas d'équivalent
/// fiable côté jeu) — volontairement omis plutôt que simulés.
class CivettaTheme implements ControlTheme {
  @override
  String get id => 'civetta';

  @override
  String get displayName => 'Civetta';

  static const _bg = Color(0xFF0A0D12);
  static const _border = Color(0x40FFFFFF);
  static const _warnBorder = Color(0xFFE23A3A);
  static const _text = Colors.white;
  static const _dim = Colors.white38;
  static const _gearYellow = Color(0xFFE8D840);

  @override
  Widget build(BuildContext context, ControlSurface surface) {
    return Stack(
      children: [
        Positioned.fill(child: surface.pedalsWidgetInvisible),

        Center(
          child: surface.modActive
              ? _Dash(
                  telemetry: surface.telemetry,
                  useKmh: surface.useKmh,
                  width: MediaQuery.of(context).size.width * 0.82,
                )
              : const Icon(Icons.info_outline, color: Colors.white24, size: 28),
        ),

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
    // Échelle relative à la largeur de référence du design d'origine (320).
    final s = (width / 320).clamp(1.0, 2.2);

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
          padding: EdgeInsets.all(8 * s),
          decoration: BoxDecoration(
            color: CivettaTheme._bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: CivettaTheme._border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RpmStrip(rpm: rpm, redline: redline, scale: s),
              SizedBox(height: 8 * s),
              Row(
                children: [
                  Expanded(
                    child: _Box(
                      label: 'RPM',
                      value: rpm.round().toString(),
                      valueFontSize: 22 * s,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    flex: 2,
                    child: _Box(
                      label: 'GEAR',
                      value: t?.gearLabel ?? '-',
                      valueColor: CivettaTheme._gearYellow,
                      valueFontSize: 40 * s,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: _Box(
                      label: 'SPEED',
                      value: speed.toString(),
                      valueFontSize: 22 * s,
                      scale: s,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6 * s),
              Row(
                children: [
                  Expanded(
                    child: _Box(
                      label: 'TEMP',
                      value: (t?.engineTemp ?? 0).round().toString(),
                      warn: (t?.engineTemp ?? 0) > 110,
                      valueFontSize: 22 * s,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: _Box(
                      label: 'FUEL',
                      value: ((t?.fuel ?? 0) * 100).round().toString(),
                      valueFontSize: 22 * s,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: _Box(
                      label: 'ABS',
                      value: (t?.absActive ?? false) ? 'ON' : 'OFF',
                      valueFontSize: 16 * s,
                      scale: s,
                    ),
                  ),
                  SizedBox(width: 6 * s),
                  Expanded(
                    child: _Box(
                      label: 'TC',
                      value: (t?.tractionControlActive ?? false) ? 'ON' : 'OFF',
                      valueFontSize: 16 * s,
                      scale: s,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Barre de régime segmentée et numérotée (1 à 8), dernier segment en
/// rouge — inspirée des afficheurs de rupteur des dashs de simracing.
class _RpmStrip extends StatelessWidget {
  final double rpm;
  final double redline;
  final double scale;
  static const int segments = 8;

  const _RpmStrip({required this.rpm, required this.redline, required this.scale});

  @override
  Widget build(BuildContext context) {
    final ratio = redline > 0 ? (rpm / redline).clamp(0.0, 1.0) : 0.0;
    final litSegments = (ratio * segments).ceil();

    return Row(
      children: List.generate(segments, (i) {
        final lit = i < litSegments;
        final isLast = i == segments - 1;
        Color color;
        if (!lit) {
          color = Colors.white10;
        } else if (isLast) {
          color = CivettaTheme._warnBorder;
        } else {
          color = Colors.white70;
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 1 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${i + 1}',
                  style: TextStyle(fontSize: 8 * scale, color: CivettaTheme._dim),
                ),
                Container(height: 8 * scale, color: color),
              ],
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
  final Color valueColor;
  final double valueFontSize;
  final bool warn;
  final double scale;

  const _Box({
    required this.label,
    required this.value,
    this.valueColor = CivettaTheme._text,
    this.valueFontSize = 22,
    this.warn = false,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5 * scale),
      decoration: BoxDecoration(
        border: Border.all(
          color: warn ? CivettaTheme._warnBorder : CivettaTheme._border,
        ),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9 * scale,
              color: CivettaTheme._dim,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            value,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
              color: warn ? CivettaTheme._warnBorder : valueColor,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
