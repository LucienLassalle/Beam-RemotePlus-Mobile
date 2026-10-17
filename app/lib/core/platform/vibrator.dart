import 'package:flutter/services.dart';

/// Variable-strength vibrations (Android amplitude control, see MainActivity).
class Vibrator {
  Vibrator._();

  static const _channel = MethodChannel('com.beamremoteplus.app/vibrator');

  /// [primitive]: name of a HapticPrimitive, played instead on the phones
  /// that have it (Android 11+); the plain pulse otherwise.
  static Future<void> pulse(int durationMs, int amplitude, {String? primitive}) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {'ms': durationMs, 'amplitude': amplitude, 'primitive': primitive});
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }
}
