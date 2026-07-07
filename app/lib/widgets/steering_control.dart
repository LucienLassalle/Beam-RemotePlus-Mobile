import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Volant : contrôle tactile (glisser horizontalement) ou par inclinaison
/// du téléphone (gyroscope), au choix. Émet une valeur 0.0 (droite) à 1.0
/// (gauche), 0.5 = centre — même convention que le protocole natif.
///
/// N'affiche aucun élément visuel (pas de volant ni de barre) : en mode
/// inclinaison, le téléphone lui-même fait office de volant ; en mode
/// tactile, seule une zone de glissement discrète est nécessaire.
class SteeringControl extends StatefulWidget {
  final ValueChanged<double> onSteeringChanged;
  final bool tiltMode;
  final double sensitivity;
  final bool invert;

  const SteeringControl({
    super.key,
    required this.onSteeringChanged,
    this.tiltMode = true,
    this.sensitivity = 0.6,
    this.invert = false,
  });

  @override
  State<SteeringControl> createState() => _SteeringControlState();
}

class _SteeringControlState extends State<SteeringControl> {
  StreamSubscription<AccelerometerEvent>? _tiltSub;

  @override
  void didUpdateWidget(covariant SteeringControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tiltMode != oldWidget.tiltMode) {
      _updateTiltSubscription();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateTiltSubscription();
  }

  void _updateTiltSubscription() {
    _tiltSub?.cancel();
    _tiltSub = null;
    if (!widget.tiltMode) {
      widget.onSteeringChanged(0.5);
      return;
    }
    _tiltSub = accelerometerEventStream().listen((event) {
      final angle =
          math.asin(
            (event.y /
                    math.sqrt(
                      event.x * event.x + event.y * event.y + event.z * event.z,
                    ))
                .clamp(-1.0, 1.0),
          ) *
          180 /
          math.pi;
      final sign = widget.invert ? 1 : -1;
      final steering =
          (sign * angle * widget.sensitivity / 75).clamp(-0.5, 0.5) + 0.5;
      widget.onSteeringChanged(steering.clamp(0.0, 1.0));
    });
  }

  void _onDrag(DragUpdateDetails details, BoxConstraints constraints) {
    final dx = details.localPosition.dx;
    widget.onSteeringChanged((dx / constraints.maxWidth).clamp(0.0, 1.0));
  }

  @override
  void dispose() {
    _tiltSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tiltMode) {
      // Rien à afficher : le téléphone est lui-même le volant.
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragUpdate: (d) => _onDrag(d, constraints),
          onHorizontalDragEnd: (_) => widget.onSteeringChanged(0.5),
          onTapDown: (d) => widget.onSteeringChanged(
            (d.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0),
          ),
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Container(width: 1, color: Colors.white24),
          ),
        );
      },
    );
  }
}
