import 'package:flutter/services.dart';

enum HardwareKey { volumeUp, volumeDown }

typedef HardwareKeyListener = void Function(HardwareKey key, bool pressed);

/// Captures the phone volume buttons while driving (MainActivity.kt consumes
/// them so the media volume does not change) and reports press/release.
class HardwareKeys {
  HardwareKeys._();

  static const _channel = MethodChannel('com.beamngremoteplus.app/hardware_keys');
  static HardwareKeyListener? _listener;

  /// Starts capturing; [listener] receives every press and release.
  static Future<void> capture(HardwareKeyListener listener) async {
    _listener = listener;
    _channel.setMethodCallHandler(_onCall);
    await _setCaptured(true);
  }

  /// Gives the volume buttons back to the system.
  static Future<void> release() async {
    _listener = null;
    _channel.setMethodCallHandler(null);
    await _setCaptured(false);
  }

  static Future<void> _setCaptured(bool captured) async {
    try {
      await _channel.invokeMethod<void>('setVolumeKeysCaptured', captured);
    } on MissingPluginException {
      // Tests / unsupported platform.
    }
  }

  static Future<void> _onCall(MethodCall call) async {
    if (call.method != 'onVolumeKey') return;
    final args = call.arguments;
    if (args is! Map) return;
    final key = args['key'] == 'up' ? HardwareKey.volumeUp : HardwareKey.volumeDown;
    _listener?.call(key, args['pressed'] == true);
  }
}
