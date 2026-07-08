import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Volant : contrôle tactile (glisser horizontalement) ou par inclinaison
/// du téléphone (accéléromètre), au choix. Émet une valeur 0.0 (droite) à
/// 1.0 (gauche), 0.5 = centre — même convention que le protocole natif.
///
/// En mode inclinaison, un filtre passe-bas (EMA) lisse les données
/// accéléromètre à alpha=0.20, éliminant le tremblement haute fréquence
/// sans introduire de lag perceptible.
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

  // Filtre EMA : la valeur filtrée converge vers la valeur brute avec ce
  // coefficient par échantillon. 0.20 = bon équilibre fluidité/réactivité.
  static const double _alpha = 0.20;
  double _filteredAngle = 0;

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
    _filteredAngle = 0;
    if (!widget.tiltMode) {
      widget.onSteeringChanged(0.5);
      return;
    }
    _tiltSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final rawAngle =
        math.asin(
          (event.y /
                  math.sqrt(
                    event.x * event.x + event.y * event.y + event.z * event.z,
                  ))
              .clamp(-1.0, 1.0),
        ) *
        180 /
        math.pi;

    _filteredAngle = _alpha * rawAngle + (1 - _alpha) * _filteredAngle;

    final sign = widget.invert ? 1 : -1;
    final steering =
        (sign * _filteredAngle * widget.sensitivity / 75)
            .clamp(-0.5, 0.5) +
        0.5;
    widget.onSteeringChanged(steering.clamp(0.0, 1.0));
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
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                Expanded(child: Container(height: 1, color: Colors.white12)),
                Container(
                  width: 2,
                  height: 20,
                  color: Colors.white38,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                Expanded(child: Container(height: 1, color: Colors.white12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
