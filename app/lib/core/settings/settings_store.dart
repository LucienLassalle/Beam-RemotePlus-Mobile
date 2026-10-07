import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Where settings are persisted (abstract so tests use memory).
abstract class SettingsStore {
  Future<Map<String, Object?>> load();
  Future<void> save(Map<String, Object?> values);
}

class SharedPreferencesSettingsStore implements SettingsStore {
  static const _key = 'settings.v1';

  @override
  Future<Map<String, Object?>> load() async {
    final raw = (await SharedPreferences.getInstance()).getString(_key);
    if (raw == null) return const {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  @override
  Future<void> save(Map<String, Object?> values) async {
    await (await SharedPreferences.getInstance()).setString(_key, jsonEncode(values));
  }
}

class MemorySettingsStore implements SettingsStore {
  Map<String, Object?> values;
  MemorySettingsStore([this.values = const {}]);

  @override
  Future<Map<String, Object?>> load() async => values;

  @override
  Future<void> save(Map<String, Object?> values) async => this.values = values;
}
