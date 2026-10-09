import 'package:flutter/services.dart';

/// Excludes screen areas (physical pixels) from Android system gestures
/// (back swipe, vendor edge panels), which otherwise steal long touches near
/// the screen edges where the pedals are. No effect before Android 10.
class GestureExclusion {
  GestureExclusion._();

  static const _channel = MethodChannel('com.beamremoteplus.app/gesture_exclusion');

  static Future<void> setRects(List<Rect> rects) async {
    try {
      await _channel.invokeMethod<void>('setExclusionRects', [
        for (final r in rects)
          {
            'left': r.left.round(),
            'top': r.top.round(),
            'right': r.right.round(),
            'bottom': r.bottom.round(),
          },
      ]);
    } on MissingPluginException {
      // Platform without implementation: nothing to exclude.
    }
  }
}
