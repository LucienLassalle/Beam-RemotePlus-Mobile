import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../pedal_mapping.dart';

/// Brake / throttle touch zones covering the whole driving screen (minus
/// what [mapping] leaves free). Multi-touch: the strongest finger in a zone
/// wins. Uses raw pointer events (Listener) so no gesture arena can cancel a
/// long press.
///
/// [visible] draws gradient-filled zones with labels; otherwise only thin
/// bars on the screen edges show the pedal positions, so dashboards stay
/// unobstructed while users still see where the pedals are.
class PedalZones extends StatefulWidget {
  final PedalMapping mapping;
  final ValueChanged<double> onBrake;
  final ValueChanged<double> onThrottle;
  final bool visible;
  final Color brakeColor;
  final Color throttleColor;

  const PedalZones({
    super.key,
    required this.mapping,
    required this.onBrake,
    required this.onThrottle,
    this.visible = false,
    this.brakeColor = Colors.redAccent,
    this.throttleColor = Colors.greenAccent,
  });

  @override
  State<PedalZones> createState() => _PedalZonesState();
}

class _PedalZonesState extends State<PedalZones> {
  final Map<int, (Pedal, double)> _pointers = {};
  double _brake = 0;
  double _throttle = 0;

  void _track(PointerEvent e, Size size) {
    final pedal = widget.mapping.pedalAt(e.localPosition.dx, size.width);
    if (pedal == null) {
      _pointers.remove(e.pointer);
    } else {
      _pointers[e.pointer] = (pedal, widget.mapping.valueAt(e.localPosition.dy, size.height));
    }
    _publish();
  }

  void _release(PointerEvent e) {
    _pointers.remove(e.pointer);
    _publish();
  }

  double _max(Pedal pedal) =>
      _pointers.values.where((p) => p.$1 == pedal).fold(0.0, (m, p) => math.max(m, p.$2));

  void _publish() {
    final brake = _max(Pedal.brake);
    final throttle = _max(Pedal.throttle);
    if (brake != _brake) widget.onBrake(brake);
    if (throttle != _throttle) widget.onThrottle(throttle);
    if (brake != _brake || throttle != _throttle) {
      setState(() {
        _brake = brake;
        _throttle = throttle;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      return Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) => _track(e, size),
        onPointerMove: (e) => _track(e, size),
        onPointerUp: _release,
        onPointerCancel: _release,
        child: IgnorePointer(
          child: CustomPaint(
            size: size,
            painter: _PedalPainter(
              mapping: widget.mapping,
              brake: _brake,
              throttle: _throttle,
              visible: widget.visible,
              brakeColor: widget.brakeColor,
              throttleColor: widget.throttleColor,
              brakeLabel: l10n.pedalBrake,
              throttleLabel: l10n.pedalThrottle,
            ),
          ),
        ),
      );
    });
  }
}

class _PedalPainter extends CustomPainter {
  final PedalMapping mapping;
  final double brake, throttle;
  final bool visible;
  final Color brakeColor, throttleColor;
  final String brakeLabel, throttleLabel;

  _PedalPainter({
    required this.mapping,
    required this.brake,
    required this.throttle,
    required this.visible,
    required this.brakeColor,
    required this.throttleColor,
    required this.brakeLabel,
    required this.throttleLabel,
  });

  static const double edgeBarWidth = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final zone = size.width * mapping.zoneFraction;
    _paintZone(canvas, size, Rect.fromLTWH(0, 0, zone, size.height), brake, brakeColor, brakeLabel, leftEdge: true);
    _paintZone(canvas, size, Rect.fromLTWH(size.width - zone, 0, zone, size.height), throttle, throttleColor, throttleLabel,
        leftEdge: false);
  }

  void _paintZone(Canvas canvas, Size size, Rect zone, double value, Color color, String label, {required bool leftEdge}) {
    final bottom = size.height * (1 - mapping.bottomDeadZone);
    final top = size.height * mapping.topDeadZone;
    final fillTop = bottom - (bottom - top) * value;
    if (visible) {
      if (value > 0) {
        final fill = Rect.fromLTRB(zone.left, fillTop, zone.right, bottom);
        canvas.drawRect(
          fill,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0.04)],
            ).createShader(fill),
        );
      }
      final line = Paint()..color = color.withValues(alpha: 0.18);
      final x = leftEdge ? zone.right : zone.left;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    // Edge bar: always drawn, it is how invisible pedals show their position.
    final barX = leftEdge ? 0.0 : size.width - edgeBarWidth;
    canvas.drawRect(Rect.fromLTWH(barX, top, edgeBarWidth, bottom - top), Paint()..color = color.withValues(alpha: 0.12));
    if (value > 0) {
      canvas.drawRect(Rect.fromLTRB(barX, fillTop, barX + edgeBarWidth, bottom), Paint()..color = color.withValues(alpha: 0.85));
    }
    final text = TextPainter(
      text: TextSpan(
        text: value > 0.02 ? '$label ${(value * 100).round()}%' : label,
        style: TextStyle(
          color: color.withValues(alpha: value > 0.02 ? 0.9 : (visible ? 0.3 : 0.18)),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = leftEdge ? edgeBarWidth + 10 : size.width - edgeBarWidth - 10 - text.width;
    text.paint(canvas, Offset(dx, size.height - text.height - 10));
  }

  @override
  bool shouldRepaint(_PedalPainter oldDelegate) =>
      oldDelegate.brake != brake || oldDelegate.throttle != throttle || oldDelegate.visible != visible || oldDelegate.mapping != mapping;
}
