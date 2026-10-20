import 'package:flutter/material.dart';

import '../pedal_mapping.dart';

/// The part of the driving screen the pedals leave free, over the video:
/// a finger swiped there turns the camera of the video, a double tap
/// recentres it. Buttons and the steering controls stay above it.
class LookZone extends StatelessWidget {
  final PedalMapping mapping;

  /// Mirrored pedals (left-handed players), see PedalZones.swapped.
  final bool swapped;

  /// Finger moved by dx, dy logical pixels.
  final void Function(double dx, double dy) onLook;
  final VoidCallback onLookEnd;
  final VoidCallback onDoubleTap;

  const LookZone({
    super.key,
    required this.mapping,
    required this.onLook,
    required this.onLookEnd,
    required this.onDoubleTap,
    this.swapped = false,
  });

  @override
  Widget build(BuildContext context) {
    var (from, to) = mapping.freeSpan;
    if (swapped) (from, to) = (1 - to, 1 - from);
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: EdgeInsets.only(left: constraints.maxWidth * from, right: constraints.maxWidth * (1 - to)),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) => onLook(d.delta.dx, d.delta.dy),
          onPanEnd: (_) => onLookEnd(),
          onDoubleTap: onDoubleTap,
        ),
      ),
    );
  }
}
