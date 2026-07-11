import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Volant : contrôle tactile (glisser horizontalement) ou par inclinaison
/// du téléphone (accéléromètre), au choix. Émet une valeur 0.0 (droite) à
/// 1.0 (gauche), 0.5 = centre — même convention que le protocole natif.
///
/// Calibration automatique : les [_calibSamples] premiers échantillons
/// établissent la position de repos (zéro absolu). La direction et le pitch
/// sont ensuite mesurés RELATIVEMENT à cette position, ce qui corrige les
/// biais d'accéléromètre et la tenue naturelle du téléphone.
class SteeringControl extends StatefulWidget {
  final ValueChanged<double> onSteeringChanged;
  final bool tiltMode;

  /// Plage de rotation "virtuelle" du volant, en degrés, au sens où
  /// l'entendent les volants de simracing (360° = arcade/rapide, 900° =
  /// simulation lourde). Le téléphone ne peut physiquement s'incliner que
  /// dans une plage confortable (~90° maxi) : cette valeur ne change donc
  /// pas la course physique du capteur, mais le "rapport" entre l'angle
  /// d'inclinaison du téléphone et le verrouillage complet — voir
  /// [maxTiltDegFor]. Plus la plage est grande, plus il faut incliner pour
  /// atteindre le plein braquage (comportement plus doux, façon volant lourd).
  final double rotationRangeDeg;
  final bool invert;
  final bool smoothing;

  final VoidCallback? onGearUp;
  final VoidCallback? onGearDown;

  /// Angle de pitch (degrés) au-delà de la position de repos pour déclencher.
  final double gearShiftThresholdDeg;

  /// Incrémentez cette valeur pour déclencher une recalibration immédiate
  /// (réinitialise la position de repos mesurée au démarrage).
  final int recalibrateCounter;

  const SteeringControl({
    super.key,
    required this.onSteeringChanged,
    this.tiltMode = true,
    this.rotationRangeDeg = 900,
    this.invert = false,
    this.smoothing = true,
    this.onGearUp,
    this.onGearDown,
    this.gearShiftThresholdDeg = 25,
    this.recalibrateCounter = 0,
  });

  /// Angle d'inclinaison réel du téléphone (degrés, par rapport au repos)
  /// nécessaire pour atteindre le verrouillage complet, pour une plage de
  /// rotation [rotationRangeDeg] donnée. Étalonné pour qu'une plage "360°"
  /// (le défaut) corresponde à ~75° d'inclinaison — une plage confortable où
  /// la direction reste proportionnelle à l'inclinaison. Exposée pour que
  /// l'écran de réglages puisse afficher la même valeur que celle réellement
  /// utilisée par le capteur.
  static double maxTiltDegFor(double rotationRangeDeg) =>
      rotationRangeDeg * (75.0 / 360.0);

  @override
  State<SteeringControl> createState() => _SteeringControlState();
}

class _SteeringControlState extends State<SteeringControl> {
  StreamSubscription<AccelerometerEvent>? _tiltSub;

  // ── Calibration ─────────────────────────────────────────────────────────
  static const int _calibSamples = 20;
  int _calibCount = 0;
  double _accumX = 0, _accumY = 0, _accumZ = 0;
  double _restX = 0, _restY = 0, _restMag = 1;
  bool _calibrated = false;

  // ── Gear shift debounce ──────────────────────────────────────────────────
  // Un seul shift par passage par la zone neutre ; + cooldown 600 ms.
  bool _gearArmed = true;
  DateTime _lastShift = DateTime.fromMillisecondsSinceEpoch(0);
  static const Duration _shiftCooldown = Duration(milliseconds: 600);
  static const double _neutralZoneDeg = 20.0;

  // ── Anti-vibration ────────────────────────────────────────────────────
  // Le bruit du capteur (micro-variations à chaque échantillon) se traduit
  // directement en tremblement du volant si on l'envoie tel quel. Un EMA
  // léger (constante de temps ~60-80 ms à la fréquence d'échantillonnage
  // "game") absorbe ce bruit sans introduire de lag perceptible sur un
  // mouvement de main volontaire, qui est bien plus lent. La zone morte
  // élimine le résidu de tremblement autour du centre (position au repos).
  static const double _emaAlpha = 0.35;
  static const double _centerDeadzoneDeg = 0.6;
  double? _smoothedRollDeg;

  // ── Rejet de secousse (main crispée lors d'un tête-à-queue) ────────────
  // Sous rotation pure, la norme du vecteur accéléromètre reste ~constante
  // (= g), seule sa direction change. Un à-coup de la main (réflexe au
  // moment d'un dérapage) ajoute une vraie accélération linéaire, qui elle
  // fait dévier la norme de sa valeur au repos — et rend l'angle calculé
  // n'importe quoi le temps de l'à-coup, alors que l'inclinaison "logique"
  // du téléphone n'a pas vraiment changé. On réduit alors la confiance
  // accordée à l'échantillon (au lieu de le figer complètement, pour ne
  // jamais cesser de suivre l'utilisateur) le temps que ça se stabilise.
  static const double _shakeSoftDeviation = 2.0; // m/s², tolérance normale
  static const double _shakeHardDeviation = 6.0; // m/s², secousse franche
  static const double _shakeMinConfidence = 0.08;

  @override
  void didUpdateWidget(covariant SteeringControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tiltMode != oldWidget.tiltMode) {
      _updateTiltSubscription();
    } else if (widget.recalibrateCounter != oldWidget.recalibrateCounter) {
      // Recalibration manuelle : réinitialise sans couper le stream.
      _resetCalibration();
    }
  }

  @override
  void initState() {
    super.initState();
    _updateTiltSubscription();
  }

  void _resetCalibration() {
    _calibCount = 0;
    _accumX = _accumY = _accumZ = 0;
    _calibrated = false;
    _gearArmed = true;
    _smoothedRollDeg = null;
  }

  void _updateTiltSubscription() {
    _tiltSub?.cancel();
    _tiltSub = null;
    _resetCalibration();
    if (!widget.tiltMode) {
      widget.onSteeringChanged(0.5);
      return;
    }
    _tiltSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(_onAccelerometerEvent);
  }

  void _onAccelerometerEvent(AccelerometerEvent event) {
    final mag = math.sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    if (mag < 0.5) return; // quasi-apesanteur, ignorer

    // ── Phase de calibration (premiers échantillons) ─────────────────────
    if (!_calibrated) {
      _accumX += event.x;
      _accumY += event.y;
      _accumZ += event.z;
      _calibCount++;
      if (_calibCount >= _calibSamples) {
        _restX = _accumX / _calibSamples;
        _restY = _accumY / _calibSamples;
        final rz = _accumZ / _calibSamples;
        _restMag = math.sqrt(_restX * _restX + _restY * _restY + rz * rz);
        if (_restMag < 0.5) _restMag = 9.81; // sécurité
        _calibrated = true;
      }
      // Pendant la calibration, émettre le centre pour ne pas avoir de
      // saut brusque au premier échantillon calibré.
      widget.onSteeringChanged(0.5);
      return;
    }

    // ── Direction (roll en mode paysage) ─────────────────────────────────
    // On mesure l'angle de roulis courant MOINS l'angle de repos calibré,
    // ce qui annule tout biais d'offset ou d'inclinaison naturelle du tél.
    final rawRollDeg =
        math.asin((event.y / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
    final restRollDeg =
        math.asin((_restY / _restMag).clamp(-1.0, 1.0)) * 180 / math.pi;
    var rollDeg = rawRollDeg - restRollDeg;

    // ── Confiance selon l'écart de norme (détection de secousse) ─────────
    final magDeviation = (mag - _restMag).abs();
    final shakeConfidence = magDeviation <= _shakeSoftDeviation
        ? 1.0
        : magDeviation >= _shakeHardDeviation
            ? _shakeMinConfidence
            : 1.0 -
                (magDeviation - _shakeSoftDeviation) /
                    (_shakeHardDeviation - _shakeSoftDeviation) *
                    (1.0 - _shakeMinConfidence);

    // ── Lissage anti-vibration (EMA) + zone morte au centre ───────────────
    // La confiance de secousse s'applique toujours (même lissage désactivé) :
    // c'est une correction de fiabilité du capteur, pas une préférence de
    // confort — elle ralentit juste la mise à jour pendant l'à-coup, sans
    // jamais figer complètement le volant.
    final baseAlpha = widget.smoothing ? _emaAlpha : 1.0;
    final alpha = baseAlpha * shakeConfidence;
    _smoothedRollDeg = _smoothedRollDeg == null
        ? rollDeg
        : _smoothedRollDeg! + alpha * (rollDeg - _smoothedRollDeg!);
    rollDeg = _smoothedRollDeg!;
    if (rollDeg.abs() < _centerDeadzoneDeg) rollDeg = 0;

    final sign = widget.invert ? 1.0 : -1.0;
    final maxDeg = SteeringControl.maxTiltDegFor(widget.rotationRangeDeg);
    final steering =
        (sign * rollDeg / maxDeg / 2).clamp(-0.5, 0.5) + 0.5;
    widget.onSteeringChanged(steering.clamp(0.0, 1.0));

    // ── Pitch (avant/arrière) → changement de rapport ────────────────────
    _checkGearShift(event, mag);
  }

  void _checkGearShift(AccelerometerEvent event, double mag) {
    if (widget.onGearUp == null && widget.onGearDown == null) return;

    // Pitch RELATIF à la position de repos calibrée.
    final rawPitchDeg =
        math.asin((event.x / mag).clamp(-1.0, 1.0)) * 180 / math.pi;
    final restPitchDeg =
        math.asin((_restX / _restMag).clamp(-1.0, 1.0)) * 180 / math.pi;
    final pitchDeg = rawPitchDeg - restPitchDeg;

    final threshold = widget.gearShiftThresholdDeg;
    final now = DateTime.now();

    if (_gearArmed) {
      if (pitchDeg < -threshold &&
          now.difference(_lastShift) >= _shiftCooldown) {
        widget.onGearUp?.call();
        _gearArmed = false;
        _lastShift = now;
      } else if (pitchDeg > threshold &&
          now.difference(_lastShift) >= _shiftCooldown) {
        widget.onGearDown?.call();
        _gearArmed = false;
        _lastShift = now;
      }
    } else if (pitchDeg.abs() < _neutralZoneDeg) {
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
    if (widget.tiltMode) return const SizedBox.shrink();

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
