import 'package:flutter/services.dart';

/// Variable-strength vibrations (Android amplitude control, see MainActivity).
class Vibrator {
  Vibrator._();

  static const _channel = MethodChannel('com.beamngremoteplus.app/vibrator');

  static Future<void> pulse(int durationMs, int amplitude) async {
    try {
      await _channel.invokeMethod<void>('vibrate', {'ms': durationMs, 'amplitude': amplitude});
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }
}
