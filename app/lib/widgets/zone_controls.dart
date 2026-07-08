import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contrôles de frein et d'accélération par zones tactiles pleine hauteur.
/// Zone gauche = frein, zone droite = accélération.
/// La valeur 0.0-1.0 est calculée depuis la position verticale du doigt
/// (haut de zone = 100%, bas = 0%). Supporte plusieurs doigts simultanés :
/// la valeur retenue est le maximum parmi les pointeurs actifs dans la zone.
///
/// Utilise [Listener] (événements pointeur bruts) pour éviter toute
/// compétition dans l'arène de gestes Flutter.
class ZoneControls extends StatefulWidget {
  final ValueChanged<double> onBrakeChanged;
  final ValueChanged<double> onThrottleChanged;

  /// Fraction de largeur d'écran occupée par chaque zone latérale.
  final double zoneFraction;

  const ZoneControls({
    super.key,
    required this.onBrakeChanged,
    required this.onThrottleChanged,
    this.zoneFraction = 0.32,
  });

  @override
  State<ZoneControls> createState() => _ZoneControlsState();
}

class _ZoneControlsState extends State<ZoneControls> {
  // pointerId → valeur (0-1)
  final Map<int, double> _leftPtrs = {};
  final Map<int, double> _rightPtrs = {};

  double _brakeVal = 0;
  double _throttleVal = 0;

  double _compute(double dy, double height) =>
      (1 - dy / height).clamp(0.0, 1.0);

  void _update(Map<int, double> ptrs, bool isLeft) {
    final v = ptrs.isEmpty ? 0.0 : ptrs.values.reduce(math.max);
    if (isLeft) {
      if (_brakeVal == v) return;
      setState(() => _brakeVal = v);
      widget.onBrakeChanged(v);
    } else {
      if (_throttleVal == v) return;
      setState(() => _throttleVal = v);
      widget.onThrottleChanged(v);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final zw = constraints.maxWidth * widget.zoneFraction;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // Zone gauche — frein
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: zw,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _leftPtrs[e.pointer] = _compute(e.localPosition.dy, h);
                  _update(_leftPtrs, true);
                },
                onPointerMove: (e) {
                  _leftPtrs[e.pointer] = _compute(e.localPosition.dy, h);
                  _update(_leftPtrs, true);
                },
                onPointerUp: (e) {
                  _leftPtrs.remove(e.pointer);
                  _update(_leftPtrs, true);
                },
                onPointerCancel: (e) {
                  _leftPtrs.remove(e.pointer);
                  _update(_leftPtrs, true);
                },
                child: _ZonePainter(
                  value: _brakeVal,
                  color: Colors.redAccent,
                  label: 'FREIN',
                  alignLabel: Alignment.bottomLeft,
                ),
              ),
            ),
            // Zone droite — accélérateur
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: zw,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (e) {
                  _rightPtrs[e.pointer] = _compute(e.localPosition.dy, h);
                  _update(_rightPtrs, false);
                },
                onPointerMove: (e) {
                  _rightPtrs[e.pointer] = _compute(e.localPosition.dy, h);
                  _update(_rightPtrs, false);
                },
                onPointerUp: (e) {
                  _rightPtrs.remove(e.pointer);
                  _update(_rightPtrs, false);
                },
                onPointerCancel: (e) {
                  _rightPtrs.remove(e.pointer);
                  _update(_rightPtrs, false);
                },
                child: _ZonePainter(
                  value: _throttleVal,
                  color: Colors.greenAccent,
                  label: 'GAZ',
                  alignLabel: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ZonePainter extends StatelessWidget {
  final double value;
  final Color color;
  final String label;
  final Alignment alignLabel;

  const _ZonePainter({
    required this.value,
    required this.color,
    required this.label,
    required this.alignLabel,
  });

  @override
  Widget build(BuildContext context) {
    final alpha = (value * 0.35 + 0.05).clamp(0.05, 0.40);
    return Stack(
      children: [
        // Fond dégradé de bas en haut proportionnel à la valeur
        Positioned.fill(
          child: CustomPaint(painter: _GradientFillPainter(value, color)),
        ),
        // Ligne de séparation subtile
        Positioned(
          top: 0,
          bottom: 0,
          left: alignLabel == Alignment.bottomLeft ? null : 0,
          right: alignLabel == Alignment.bottomLeft ? 0 : null,
          width: 1,
          child: Container(color: color.withValues(alpha: 0.15)),
        ),
        // Label + pourcentage en bas
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color.withValues(alpha: value > 0.05 ? 0.9 : 0.25),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              if (value > 0.02)
                Text(
                  '${(value * 100).round()}%',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GradientFillPainter extends CustomPainter {
  final double value;
  final Color color;
  const _GradientFillPainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (value <= 0) return;
    final fillHeight = size.height * value;
    final rect = Rect.fromLTWH(0, size.height - fillHeight, size.width, fillHeight);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.05),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(_GradientFillPainter old) =>
      old.value != value || old.color != color;
}
