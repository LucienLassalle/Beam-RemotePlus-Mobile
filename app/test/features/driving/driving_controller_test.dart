import 'package:beam_remoteplus/core/network/remote_link.dart';
import 'package:beam_remoteplus/core/platform/hardware_keys.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
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
    // 720p 60 on a 16:9 screen (the default until the screen is known).
    const hd = PovFormat(PovQuality.hd60, 1280, 720);

    Future<void> session({bool pov = true}) async {
      link.events_.add(SessionMessage(commands: [if (pov) 'pov', 'horn']));
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> state(String state, {bool inside = false, String? error}) async {
      link.events_.add(PovMessage(state: state, inside: inside, error: error));
      await Future<void>.delayed(Duration.zero);
    }

    Future<void> picture({String? error}) async {
      link.povPictures_.add(PovPicture(textureId: 7, width: 1280, height: 720, error: error));
      await Future<void>.delayed(Duration.zero);
    }

    test('is asked for only when the setting is on and the mod offers it', () async {
      await session(pov: false);
      controller.settings = const AppSettings(povVideo: true);
      expect(link.povRequests, isEmpty);
      expect(controller.povAvailable, isFalse);
      await session();
      expect(controller.povAvailable, isTrue);
      expect(link.povRequests, [hd]);
    });

    test('says why the game cannot stream it, until it can', () async {
      expect(controller.povUnavailable, isNull);
      link.events_.add(const SessionMessage(commands: ['horn'], povUnavailable: 'platform'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.povAvailable, isFalse);
      expect(controller.povUnavailable, 'platform');
      await session();
      expect(controller.povUnavailable, isNull);
    });

    test('is asked for again on each session, the mod may have restarted', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await session();
      expect(link.povRequests, [hd, hd]);
    });

    test('is asked for again in another quality', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      controller.settings = const AppSettings(povVideo: true, povQuality: PovQuality.fullHd60);
      expect(link.povRequests, [hd, const PovFormat(PovQuality.fullHd60, 1920, 1080)]);
    });

    test('is asked for again at another bitrate', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      controller.settings = const AppSettings(povVideo: true, povBitrate: PovBitrate.high);
      expect(link.povRequests, [hd, const PovFormat(PovQuality.hd60, 1280, 720, PovBitrate.high)]);
    });

    test('is asked for in the shape of the screen, again when it changes', () async {
      controller.settings = const AppSettings(povVideo: true);
      controller.screenAspect = 20 / 9;
      await session();
      expect(link.povRequests, [const PovFormat(PovQuality.hd60, 1424, 640)]);
      controller.screenAspect = 20 / 9;
      expect(link.povRequests, hasLength(1));
      controller.screenAspect = 2176 / 1812; // folding phone opened
      expect(link.povRequests.last, const PovFormat(PovQuality.hd60, 1048, 872));
    });

    test('shows the picture of the player, and tells the kind of camera once live', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await picture();
      expect(controller.povPicture?.textureId, 7);
      expect(controller.povInside, isNull);
      await state(PovMessage.live, inside: true);
      expect(controller.povInside, isTrue);
      await state(PovMessage.live);
      expect(controller.povInside, isFalse);
      expect(controller.povError, isNull);
    });

    test('tells why there is no video', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await state(PovMessage.failed, error: PovMessage.errorEncoder);
      expect(controller.povError, PovMessage.errorEncoder);
      expect(controller.povInside, isNull);
      controller.settings = const AppSettings();
      expect(controller.povError, isNull);
    });

    test('tells when the phone cannot decode it', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await picture(error: 'create: no decoder');
      expect(controller.povError, DrivingController.povErrorDecoder);
    });

    test('stops when the setting is switched off, and forgets the picture', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      await picture();
      controller.settings = const AppSettings();
      expect(link.povRequests, [hd, null]);
      expect(controller.povPicture, isNull);
    });

    test('stops without the mod', () async {
      controller.settings = const AppSettings(povVideo: true);
      await session();
      link.modActive = false;
      link.modActive_.add(false);
      await Future<void>.delayed(Duration.zero);
      expect(link.povRequests, [hd, null]);
      expect(controller.povAvailable, isFalse);
    });
  });

  group('camera of the video', () {
    Future<void> video({bool look = true, bool inside = false, bool free = false}) async {
      controller.settings = const AppSettings(povVideo: true);
      link.events_.add(SessionMessage(commands: ['pov', if (look) 'look']));
      link.events_.add(PovMessage(state: PovMessage.live, inside: inside, free: free));
      await Future<void>.delayed(Duration.zero);
      link.commands.clear();
    }

    test('only with a mod that offers it', () async {
      await video(look: false);
      expect(controller.povCameraControl, isFalse);
      controller.look(10, 0);
      controller.recenterLook();
      expect(link.commands, isEmpty);
    });

    test('finger moves are gathered, then sent', () async {
      await video();
      controller.look(3, 1);
      controller.look(2, -0.5);
      expect(link.commands, isEmpty);
      await Future<void>.delayed(DrivingController.lookInterval * 2);
      expect(link.commands, ['look|10|1']);
    });

    test('a seat camera turns back to the road a moment after the finger leaves', () async {
      await video(inside: true);
      controller.look(4, 0);
      controller.lookEnded();
      controller.look(1, 0); // the finger is back: no recentring yet
      controller.lookEnded();
      await Future<void>.delayed(DrivingController.lookInterval * 2);
      expect(link.commands, ['look|10|0']);
      await Future<void>.delayed(DrivingController.recenterDelay);
      expect(link.commands, ['look|10|0', 'look_center']);
    });

    test('other cameras stay where they were left, a double tap recentres them', () async {
      await video();
      controller.lookEnded();
      expect(link.commands, isEmpty);
      controller.recenterLook();
      expect(link.commands, ['look_center']);
    });

    test('the free camera is switched on and off', () async {
      await video();
      controller.toggleFreeCamera();
      link.events_.add(const PovMessage(state: PovMessage.live, free: true));
      await Future<void>.delayed(Duration.zero);
      expect(controller.freeCamera, isTrue);
      controller.toggleFreeCamera();
      expect(link.commands, ['freecam|1', 'freecam|0']);
    });

    test('in the free camera the pedals fly it and the car coasts, wheels straight', () async {
      await video();
      controller.throttle(0.8);
      controller.steer(0.2);
      link.events_.add(const PovMessage(state: PovMessage.live, free: true));
      await Future<void>.delayed(Duration.zero);
      expect((link.throttle, link.brake, link.steering), (0, 0, 0.5));
      controller.throttle(1);
      controller.brake(0.25);
      controller.steer(0.9);
      expect(link.commands, ['fly|1.00', 'fly|0.75']);
      expect((link.throttle, link.brake, link.steering), (0, 0, 0.5));
      await Future<void>.delayed(DrivingController.flyRepeat * 1.5);
      expect(link.commands.last, 'fly|0.75'); // repeated while held
      controller.throttle(0);
      controller.brake(0);
      expect(link.commands.last, 'fly|0.00');
    });
  });
}
