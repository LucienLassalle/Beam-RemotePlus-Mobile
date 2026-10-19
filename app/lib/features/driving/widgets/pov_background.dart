import 'package:flutter/material.dart';

import '../../../core/network/remote_link.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../driving_controller.dart';

/// Point of view video of the mod (the view from the driver's seat), drawn
/// by the phone's hardware decoder into a texture, filling the screen
/// behind the controls.
class PovBackground extends StatelessWidget {
  final PovPicture picture;

  const PovBackground({super.key, required this.picture});

  @override
  Widget build(BuildContext context) {
    if (picture.width <= 0 || picture.height <= 0) return const SizedBox.shrink();
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: picture.width.toDouble(),
          height: picture.height.toDouble(),
          child: Texture(textureId: picture.textureId, filterQuality: FilterQuality.medium),
        ),
      ),
    );
  }
}

/// Why the point of view video is missing, and what to do about it.
class PovErrorBanner extends StatelessWidget {
  final String error;

  const PovErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = error == DrivingController.povErrorDecoder ? l10n.povErrorDecoder : l10n.povErrorEncoder;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off, color: Colors.orangeAccent),
          const SizedBox(width: 10),
          Flexible(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
      ),
    );
  }
}
