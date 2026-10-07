import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('round-trips through JSON', () {
      const s = AppSettings(themeName: 'Civetta', localeCode: 'fr', rotationRangeDeg: 540, volumeKeys: false);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.themeName, 'Civetta');
      expect(back.localeCode, 'fr');
      expect(back.rotationRangeDeg, 540);
      expect(back.volumeKeys, isFalse);
    });

    test('falls back to defaults for missing or invalid values', () {
      final s = AppSettings.fromJson({'useKmh': 'yes', 'rotationRangeDeg': 123, 'themeName': 4});
      expect(s.useKmh, isTrue);
      expect(s.rotationRangeDeg, 900);
      expect(s.themeName, 'Default');
      expect(s.localeCode, isNull);
    });

    test('copyWith can reset the language to the phone language', () {
      const s = AppSettings(localeCode: 'fr');
      expect(s.copyWith(localeCode: null).localeCode, isNull);
      expect(s.copyWith(useKmh: false).localeCode, 'fr');
    });

    test('volume buttons and vehicle buttons are on by default', () {
      expect(const AppSettings().volumeKeys, isTrue);
      expect(const AppSettings().showActionsBar, isTrue);
    });
  });

  group('SettingsController', () {
    test('loads, notifies and saves every change', () async {
      final store = MemorySettingsStore({'themeName': 'F4'});
      final controller = SettingsController(store);
      var notified = 0;
      controller.addListener(() => notified++);
      await controller.load();
      expect(controller.settings.themeName, 'F4');
      await controller.update((s) => s.copyWith(useKmh: false));
      expect(store.values['useKmh'], isFalse);
      expect(notified, 2);
    });
  });
}
