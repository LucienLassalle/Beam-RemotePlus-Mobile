import 'dart:typed_data';

import 'package:beam_remoteplus/core/platform/hardware_keys.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/core/protocol/vehicle_command.dart';
import 'package:beam_remoteplus/core/protocol/vehicle_skeleton.dart';
import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/features/driving/driving_controller.dart';
import 'package:beam_remoteplus/themes/control_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';

void main() {
  late FakeLink link;
  late DrivingController controller;
  var limiterHits = 0;

  setUp(() {
    link = FakeLink();
    limiterHits = 0;
    controller = DrivingController(link: link, settings: const AppSettings(hapticLimiter: true), onLimiter: () => limiterHits++);
  });

  tearDown(() {
    controller.dispose();
    link.dispose();
  });

  test('forwards analog inputs', () {
    controller.steer(0.2);
    controller.throttle(0.7);
    controller.brake(0.1);
    expect([link.steering, link.throttle, link.brake], [0.2, 0.7, 0.1]);
  });

  test('volume up holds the horn, volume down flashes the high beams', () {
    controller.onHardwareKey(HardwareKey.volumeUp, true);
    controller.onHardwareKey(HardwareKey.volumeUp, true); // repeated press: ignored
    controller.onHardwareKey(HardwareKey.volumeUp, false);
    controller.onHardwareKey(HardwareKey.volumeDown, true);
    controller.onHardwareKey(HardwareKey.volumeDown, false);
    expect(link.commands, ['horn|1', 'horn|0', 'highbeam|1', 'highbeam|0']);
  });

  test('horn and headlight flash on the volume buttons can be disabled separately', () {
    controller.settings = const AppSettings(hornOnVolume: false);
    controller.onHardwareKey(HardwareKey.volumeUp, true);
    expect(link.commands, isEmpty);
    controller.onHardwareKey(HardwareKey.volumeDown, true);
    expect(link.commands, ['highbeam|1']);
    controller.onHardwareKey(HardwareKey.volumeDown, false);
    controller.settings = const AppSettings(flashOnVolume: false);
    controller.onHardwareKey(HardwareKey.volumeDown, true);
    expect(link.commands, ['highbeam|1', 'highbeam|0']);
  });

  test('on the F4 theme, volume up opens the DRS and volume down starts the Push-to-Pass', () async {
    controller.settings = const AppSettings(themeName: 'F4');
    link.telemetry_.add(const Telemetry(hasDrs: true, hasPushToPass: true));
    await Future<void>.delayed(Duration.zero);
    controller.onHardwareKey(HardwareKey.volumeUp, true);
    controller.onHardwareKey(HardwareKey.volumeUp, false);
    controller.onHardwareKey(HardwareKey.volumeDown, true);
    controller.onHardwareKey(HardwareKey.volumeDown, false);
    expect(link.commands, ['drs', 'push_to_pass']);
  });

  test('on the F4 theme, the volume buttons do nothing on a car without DRS nor Push-to-Pass', () async {
    controller.settings = const AppSettings(themeName: 'F4');
    link.telemetry_.add(const Telemetry(hasPitLimiter: true));
    await Future<void>.delayed(Duration.zero);
    controller.onHardwareKey(HardwareKey.volumeUp, true);
    controller.onHardwareKey(HardwareKey.volumeDown, true);
    expect(link.commands, isEmpty);
  });

  test('steering goes through the centre precision setting', () {
    controller.settings = const AppSettings(steeringCenterPrecision: 1);
    controller.steer(0.75);
    expect(link.steering, lessThan(0.75));
    expect(link.steering, greaterThan(0.5));
  });

  test('a held More command is released with the other holds', () {
    const crane = VehicleCommand(id: 'v:crane', hold: true);
    controller.holdMore(crane, pressed: true);
    controller.holdMore(crane, pressed: true); // repeated: ignored
    controller.releaseAllHolds();
    expect(link.commands, ['action_down|v:crane', 'action_up|v:crane']);
  });

  test('read-only releases holds, centres the controls and blocks inputs', () {
    controller.hold('horn', pressed: true);
    controller.throttle(1);
    controller.setReadOnly(true);
    expect(link.commands, ['horn|1', 'horn|0']);
    expect(link.throttle, 0);
    controller.throttle(1);
    controller.press('hazard');
    expect(link.throttle, 0);
    expect(link.commands.length, 2);
  });

  test('commands need the mod', () {
    link.modActive = false;
    controller.press('hazard');
    controller.hold('horn', pressed: true);
    expect(link.commands, isEmpty);
  });

  test('a release is always sent for a press, even after losing the mod', () {
    controller.hold('horn', pressed: true);
    link.modActive = false;
    controller.hold('horn', pressed: false);
    expect(link.commands, ['horn|1', 'horn|0']);
  });

  test('gear shift sends the command and flashes', () async {
    controller.shift(up: true);
    expect(link.commands, ['gear_up']);
    expect(controller.gearFlash, GearFlash.up);
    await Future<void>.delayed(DrivingController.flashDuration + const Duration(milliseconds: 50));
    expect(controller.gearFlash, isNull);
  });

  test('vibrates once per hit of the rev limiter', () async {
    for (final rpm in const <double>[7000, 7900, 7950, 7600, 7900, 7300, 7900]) {
      link.telemetry_.add(Telemetry(rpm: rpm, maxRpm: 8000));
    }
    await Future<void>.delayed(Duration.zero);
    // 7900 hits, 7950 stays on it, 7600 is not low enough to re-arm,
    // 7300 re-arms, 7900 hits again.
    expect(limiterHits, 2);
  });

  test('the limiter vibration is off by default', () async {
    controller.settings = const AppSettings();
    link.telemetry_.add(const Telemetry(rpm: 8000, maxRpm: 8000));
    await Future<void>.delayed(Duration.zero);
    expect(limiterHits, 0);
  });

  test('asks for the vehicle skeleton, even in read-only, and exposes it once received', () async {
    controller.setReadOnly(true);
    link.telemetry_.add(const Telemetry(skeletonId: 'a', skeletonDamage: '9'));
    await Future<void>.delayed(Duration.zero);
    expect(link.commands, ['skeleton']);
    expect(controller.skeleton, isNull);
    link.events_.add(const SkeletonMessage(SkeletonChunk(id: 'a', offset: 0, count: 1, seg: [0, 0, 100, 0])));
    await Future<void>.delayed(Duration.zero);
    expect(controller.skeleton!.id, 'a');
    expect(controller.skeletonLevels, [9]);
  });

  test('keeps the state of the optional mods, unknown until the mod tells', () async {
    expect(controller.optionalMods, isNull);
    link.events_.add(const SessionMessage(modVersion: '0.0.4'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.optionalMods, isNull);
    link.events_.add(const SessionMessage(optionalMods: {'fr17': 'enabled'}));
    await Future<void>.delayed(Duration.zero);
    expect(controller.optionalMods, {'fr17': 'enabled'});
  });

  group('point of view video', () {
    Future<void> session({bool pov = true}) async {
      link.events_.add(SessionMessage(commands: [if (pov) 'pov', 'horn']));
      await Future<void>.delayed(Duration.zero);
    }

    test('is asked for only when the setting is on and the mod offers it', () async {
      await session(pov: false);
      controller.settings = const AppSettings(povVideo: true);
      expect(link.povRequests, isEmpty);
      expect(controller.povAvailable, isFalse);
      await session();
      expect(controller.povAvailable, isTrue);
      expect(link.povRequests, [true]);
    });

    test('is asked for again on each session, the mod may have restarted', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await session();
      expect(link.povRequests, [true, true]);
    });

    test('stops when the setting is switched off, and forgets the last frame', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      link.povFrames_.add(Uint8List.fromList([1, 2]));
      await Future<void>.delayed(Duration.zero);
      expect(controller.povFrame.value, [1, 2]);
      controller.settings = const AppSettings();
      expect(link.povRequests, [true, false]);
      expect(controller.povFrame.value, isNull);
    });

    test('stops without the mod', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      link.modActive = false;
      link.modActive_.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(link.povRequests, [true, false]);
      expect(controller.povAvailable, isFalse);
    });
  });
}
