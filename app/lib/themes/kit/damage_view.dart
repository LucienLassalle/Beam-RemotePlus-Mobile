import 'package:flutter/material.dart';

import '../../core/protocol/telemetry.dart';

/// Top-down damage schematic: the six body zones coloured from green
/// (intact) to red (wrecked), a tyre at each corner coloured by temperature
/// (blue = cold, green = working temperature, red = overheating, with the
/// wear % when the tyre mod is installed) and flat tyres crossed out.
class DamageView extends StatelessWidget {
  final Telemetry telemetry;
  const DamageView({super.key, required this.telemetry});

  static Color damageColor(double damage) =>
      Color.lerp(const Color(0xFF2E7D32), Colors.redAccent, (damage * 3).clamp(0.0, 1.0))!;

  static Color heatColor(double? heat) {
    if (heat == null) return Colors.white24;
    if (heat < 0) return Color.lerp(Colors.greenAccent, Colors.lightBlueAccent, -heat)!;
    return Color.lerp(Colors.greenAccent, Colors.redAccent, heat)!;
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 0.62,
        child: CustomPaint(painter: _DamagePainter(telemetry)),
      );
}

class _DamagePainter extends CustomPainter {
  final Telemetry t;
  _DamagePainter(this.t);

  static const _zones = [
    ['FL', 'FR'],
    ['ML', 'MR'],
    ['RL', 'RR'],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(size.width * 0.2, size.height * 0.04, size.width * 0.6, size.height * 0.92);
    final zoneW = body.width / 2, zoneH = body.height / 3;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < 2; col++) {
        final zone = _zones[row][col];
        final r = Rect.fromLTWH(body.left + col * zoneW, body.top + row * zoneH, zoneW, zoneH).deflate(1.5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = DamageView.damageColor(t.bodyDamage?[zone] ?? 0).withValues(alpha: 0.8),
        );
      }
    }
    // Tyres
    final tyreW = size.width * 0.16, tyreH = size.height * 0.2;
    final corners = {
      'FL': Offset(body.left - tyreW * 0.55, body.top + zoneH * 0.5),
      'FR': Offset(body.right + tyreW * 0.55, body.top + zoneH * 0.5),
      'RL': Offset(body.left - tyreW * 0.55, body.bottom - zoneH * 0.5),
      'RR': Offset(body.right + tyreW * 0.55, body.bottom - zoneH * 0.5),
    };
    corners.forEach((name, c) {
      final r = Rect.fromCenter(center: c, width: tyreW, height: tyreH);
      final flat = t.flatTires.contains(name);
      final tyre = t.tyres?[name];
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = flat ? Colors.redAccent : DamageView.heatColor(tyre?.heat),
      );
      if (flat) {
        final x = Paint()
          ..color = Colors.black
          ..strokeWidth = 2;
        canvas.drawLine(r.topLeft, r.bottomRight, x);
        canvas.drawLine(r.topRight, r.bottomLeft, x);
      }
      final label = tyre?.temp != null ? '${tyre!.temp!.round()}°' : null;
      if (label != null) {
        final tp = TextPainter(
          text: TextSpan(text: label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'Roboto')),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = name.endsWith('L') ? r.left - tp.width - 2 : r.right + 2;
        tp.paint(canvas, Offset(dx, c.dy - tp.height / 2));
      }
    });
  }

  @override
  bool shouldRepaint(_DamagePainter oldDelegate) => true;
}
