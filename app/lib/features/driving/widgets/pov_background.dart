import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Point of view video of the mod (the view from the driver's seat), filling
/// the screen behind the controls. Only this widget rebuilds on each frame.
class PovBackground extends StatelessWidget {
  final ValueListenable<Uint8List?> frame;

  const PovBackground({super.key, required this.frame});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Uint8List?>(
      valueListenable: frame,
      builder: (context, jpeg, _) {
        if (jpeg == null) return const SizedBox.shrink();
        return Image.memory(
          jpeg,
          fit: BoxFit.cover,
          // Keeps the previous frame on screen while the next one decodes.
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        );
      },
    );
  }
}
