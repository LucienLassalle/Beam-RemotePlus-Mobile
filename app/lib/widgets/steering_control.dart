import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Volant : contrôle tactile (glisser horizontalement) ou par inclinaison
/// du téléphone (accéléromètre), au choix. Émet une valeur 0.0 (droite) à
/// 1.0 (gauche), 0.5 = centre — même convention que le protocole natif.
///
/// Pas de filtre EMA supplémentaire : Android filtre déjà en interne, et
/// tout filtre applicatif introduit exactement la "linéarité" (lag sur
/// changement brusque de direction) que l'on cherche à éviter.
///
/// Fonctionnalité optionnelle : changement de rapport par pitch.
/// Pencher le téléphone vers l'avant = montée de rapport, vers l'arrière =
/// descente. Activé uniquement si [onGearUp]/[onGearDown] sont fournis.
class SteeringControl extends StatefulWidget {
  final ValueChanged<double> onSteeringChanged;
  final bool tiltMode;
  final double sensitivity;
  final bool invert;

  /// Si non null, un pitch > [gearShiftThresholdDeg] déclenche onGearUp.
  final VoidCallback? onGearUp;

  /// Si non null, un pitch < -[gearShiftThresholdDeg] déclenche onGearDown.
  final VoidCallback? onGearDown;

  /// Angle de pitch (degrés) à dépasser pour déclencher un changement.
  final double gearShiftThresholdDeg;

  const SteeringControl({
    super.key,
    required this.onSteeringChanged,
    this.tiltMode = true,
    this.sensitivity = 0.6,
    this.invert = false,
    this.onGearUp,
    this.onGearDown,
    this.gearShiftThresholdDeg = 28,
  });

  @override
  State<SteeringControl> createState() => _SteeringControlState();
}

class _SteeringControlState extends State<SteeringControl> {
  StreamSubscription<AccelerometerEvent>? _tiltSub;

  // Debounce gear shift : on ne peut déclencher qu'un shift par passage
  // par la zone neutre (évite les shifts répétés tant qu'incliné).
  bool _gearArmed = true; // true = prêt à déclencher un shift

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
    _gearArmed = true;
    if (!widget.tiltMode) {
      widget.onSteeringChanged(0.5);
      return;
    }
    _tiltSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    // ── Direction (roll en mode paysage) ───────────────────────────────
    final magnitude = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (magnitude < 0.01) return; // téléphone en apesanteur, ignorer

    final rollAngle =
        math.asin((event.y / magnitude).clamp(-1.0, 1.0)) * 180 / math.pi;
    final sign = widget.invert ? 1 : -1;
    final steering =
        (sign * rollAngle * widget.sensitivity / 75).clamp(-0.5, 0.5) + 0.5;
    widget.onSteeringChanged(steering.clamp(0.0, 1.0));

    // ── Pitch (avant/arrière) → changement de rapport ─────────────────
    _checkGearShift(event, magnitude);
  }

  // En mode paysage gauche, l'axe X du capteur mesure le pitch
  // (inclinaison avant/arrière du téléphone).
  // Valeur positive = haut de l'écran incliné vers l'utilisateur (recul).
  // Valeur négative = haut de l'écran éloigné (avancée).
  void _checkGearShift(AccelerometerEvent event, double magnitude) {
    if (widget.onGearUp == null && widget.onGearDown == null) return;

    final pitchAngle =
        math.asin((event.x / magnitude).clamp(-1.0, 1.0)) * 180 / math.pi;
    final threshold = widget.gearShiftThresholdDeg;
    const neutral = 15.0; // zone morte de retour

    if (_gearArmed) {
      if (pitchAngle < -threshold) {
        // Avant → montée de rapport
        widget.onGearUp?.call();
        _gearArmed = false;
      } else if (pitchAngle > threshold) {
        // Arrière → descente de rapport
        widget.onGearDown?.call();
        _gearArmed = false;
      }
    } else if (pitchAngle.abs() < neutral) {
      // Retour en position neutre → prêt pour le prochain shift
      _gearArmed = true;
    }
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
