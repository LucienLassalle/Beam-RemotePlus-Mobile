import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../tilt_steering.dart';

/// Steering input: phone tilt (accelerometer) or a horizontal touch bar.
/// Emits 0 (full right) .. 1 (full left), 0.5 = centre. In tilt mode the
/// widget draws nothing.
class SteeringControl extends StatefulWidget {
  final ValueChanged<double> onSteering;
  final bool tiltMode;
  final double rotationRangeDeg;
  final bool invert;
  final bool smoothing;

  /// Non-null enables pitch gear shifting (+1 up, -1 down).
  final ValueChanged<int>? onPitchShift;

  /// Increment to recalibrate the resting position.
  final int recalibrateCounter;

  /// Accelerometer samples; defaults to the phone sensor (tests inject one).
  final Stream<AccelerometerEvent>? accelerometer;

  const SteeringControl({
    super.key,
    required this.onSteering,
    this.tiltMode = true,
    this.rotationRangeDeg = 900,
    this.invert = false,
    this.smoothing = true,
    this.onPitchShift,
    this.recalibrateCounter = 0,
    this.accelerometer,
  });

  @override
  State<SteeringControl> createState() => _SteeringControlState();
}

class _SteeringControlState extends State<SteeringControl> {
  StreamSubscription<AccelerometerEvent>? _sub;
  final TiltSteering _tilt = TiltSteering();
  final PitchShifter _shifter = PitchShifter();

  @override
  void initState() {
    super.initState();
    _configure();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant SteeringControl old) {
    super.didUpdateWidget(old);
    _configure();
    if (widget.tiltMode != old.tiltMode) {
      _subscribe();
    } else if (widget.recalibrateCounter != old.recalibrateCounter) {
      _tilt.recalibrate();
    }
  }

  void _configure() {
    _tilt
      ..rotationRangeDeg = widget.rotationRangeDeg
      ..invert = widget.invert
      ..smoothing = widget.smoothing;
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = null;
    _tilt.recalibrate();
    if (!widget.tiltMode) {
      widget.onSteering(0.5);
      return;
    }
    final samples = widget.accelerometer ?? accelerometerEventStream(samplingPeriod: SensorInterval.gameInterval);
    _sub = samples.listen(_onSample);
  }

  void _onSample(AccelerometerEvent e) {
    widget.onSteering(_tilt.steering(e.x, e.y, e.z));
    final onShift = widget.onPitchShift;
    if (onShift == null) return;
    final direction = _shifter.update(_tilt.pitch(e.x, e.y, e.z), DateTime.now());
    if (direction != 0) onShift(direction);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tiltMode) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, constraints) {
      double valueAt(double dx) => (dx / constraints.maxWidth).clamp(0.0, 1.0);
      return GestureDetector(
        onHorizontalDragUpdate: (d) => widget.onSteering(valueAt(d.localPosition.dx)),
        onHorizontalDragEnd: (_) => widget.onSteering(0.5),
        onTapDown: (d) => widget.onSteering(valueAt(d.localPosition.dx)),
        onTapUp: (_) => widget.onSteering(0.5),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          alignment: Alignment.center,
          child: Container(width: 2, height: 22, color: Colors.white38),
        ),
      );
    });
  }
}
