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
///
/// Pas de filtre EMA : Android filtre déjà en interne, et tout filtre
/// applicatif réintroduit le "lag sur changement de direction".
class SteeringControl extends StatefulWidget {
  final ValueChanged<double> onSteeringChanged;
  final bool tiltMode;
  final double sensitivity;
  final bool invert;

  final VoidCallback? onGearUp;
  final VoidCallback? onGearDown;

  /// Angle de pitch (degrés) au-delà de la position de repos pour déclencher.
  final double gearShiftThresholdDeg;

  const SteeringControl({
    super.key,
    required this.onSteeringChanged,
    this.tiltMode = true,
    this.sensitivity = 0.6,
    this.invert = false,
    this.onGearUp,
    this.onGearDown,
    this.gearShiftThresholdDeg = 25,
  });

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

  @override
  void didUpdateWidget(covariant SteeringControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tiltMode != oldWidget.tiltMode) _updateTiltSubscription();
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
    final rollDeg = rawRollDeg - restRollDeg;

    final sign = widget.invert ? 1.0 : -1.0;
    // sensitivity=1.0 → ±45° = lock complet ; 0.6 → ±75°.
    final maxDeg = 45.0 / widget.sensitivity;
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
