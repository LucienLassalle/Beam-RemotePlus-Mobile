import 'package:flutter/services.dart';

/// Exclut des zones de l'écran (en pixels physiques) des gestes système
/// Android (retour arrière, panneaux latéraux constructeur...), qui sinon
/// interceptent le toucher lors d'un appui prolongé près des bords/coins
/// de l'écran. Sans effet avant Android 10 (API 29) ni sur iOS.
class GestureExclusion {
  GestureExclusion._();

  static const _channel = MethodChannel(
    'com.beamngremoteplus.app/gesture_exclusion',
  );

  static Future<void> setRects(List<Rect> rects) async {
    try {
      await _channel.invokeMethod('setExclusionRects', [
        for (final r in rects)
          {
            'left': r.left.round(),
            'top': r.top.round(),
            'right': r.right.round(),
            'bottom': r.bottom.round(),
          },
      ]);
    } on MissingPluginException {
      // iOS / plateforme sans implémentation : pas d'effet, pas grave.
    }
  }
}
