import 'package:flutter/material.dart';

import 'app.dart';
import 'core/debug/debug_log.dart';
import 'core/settings/settings_controller.dart';
import 'core/settings/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(SharedPreferencesSettingsStore());
  await settings.load();
  DebugLog.enabled = settings.settings.debugMode;
  runApp(BeamRemotePlusApp(settings: settings));
}
