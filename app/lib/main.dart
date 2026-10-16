import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/debug/debug_log.dart';
import 'core/platform/app_version.dart';
import 'core/settings/settings_controller.dart';
import 'core/settings/settings_store.dart';
import 'core/version/update_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = SettingsController(const SharedPreferencesSettingsStore());
  await settings.load();
  DebugLog.enabled = settings.settings.debugMode;
  final updates = UpdateController(
    source: GitHubReleaseSource(),
    cache: const SharedPreferencesSettingsStore('releases.v1'),
    appVersion: await resolveAppVersion(),
  );
  await updates.load();
  if (settings.settings.checkUpdates) unawaited(updates.check());
  runApp(BeamRemotePlusApp(settings: settings, updates: updates));
}
