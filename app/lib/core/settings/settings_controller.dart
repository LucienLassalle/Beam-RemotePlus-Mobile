import 'package:flutter/foundation.dart';

import 'app_settings.dart';
import 'settings_store.dart';

/// Holds the current [AppSettings] and saves every change.
class SettingsController extends ChangeNotifier {
  final SettingsStore _store;
  AppSettings _settings = const AppSettings();

  SettingsController(this._store);

  AppSettings get settings => _settings;

  Future<void> load() async {
    _settings = AppSettings.fromJson(await _store.load());
    notifyListeners();
  }

  /// `controller.update((s) => s.copyWith(useKmh: false))`
  Future<void> update(AppSettings Function(AppSettings current) change) async {
    final next = change(_settings);
    _settings = next;
    notifyListeners();
    await _store.save(next.toJson());
  }
}
