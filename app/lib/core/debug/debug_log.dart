import 'package:flutter/foundation.dart';

/// Verbose connection logs (visible with `adb logcat`), enabled with the
/// debug mode. Kept in the code permanently instead of ad-hoc prints.
class DebugLog {
  DebugLog._();

  static bool enabled = false;

  static void log(String message) {
    if (enabled) debugPrint('BeamRemotePlus: $message');
  }
}
