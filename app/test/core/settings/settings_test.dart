import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('round-trips through JSON', () {
      const s = AppSettings(
        themeName: 'Civetta',
        localeCode: 'fr',
        rotationRangeDeg: 1080,
        hornOnVolume: false,
        hapticKerbs: false,
        hapticLimiter: true,
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.themeName, 'Civetta');
      expect(back.localeCode, 'fr');
      expect(back.rotationRangeDeg, 1080);
      expect(back.hornOnVolume, isFalse);
      expect(back.flashOnVolume, isTrue);
      expect(back.hapticKerbs, isFalse);
      expect(back.hapticLimiter, isTrue);
    });

    test('falls back to defaults for missing or invalid values', () {
      final s = AppSettings.fromJson({'useKmh': 'yes', 'rotationRangeDeg': 10, 'themeName': 4});
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

    test('defaults asked for', () {
      const s = AppSettings();
      expect(s.tiltSteering, isTrue);
      expect(s.useKmh, isTrue);
      expect(s.secondScreen, isFalse);
      expect(s.steeringSmoothing, isTrue);
      expect(s.pitchGearShift, isFalse);
      expect([s.hapticSpin, s.hapticLock, s.hapticImpacts, s.hapticKerbs], everyElement(isTrue));
      expect(s.hapticLimiter, isFalse);
      expect(s.hornOnVolume && s.flashOnVolume, isTrue);
      expect(s.debugMode, isFalse);
      expect(s.showActionsBar, isTrue);
    });

    test('settings saved by version 2.0 carry over', () {
      final s = AppSettings.fromJson({'volumeKeys': false, 'roadHaptics': false, 'shiftHaptics': true});
      expect(s.hornOnVolume || s.flashOnVolume, isFalse);
      expect(s.anyRoadHaptics, isFalse);
      expect(s.hapticLimiter, isTrue);
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
