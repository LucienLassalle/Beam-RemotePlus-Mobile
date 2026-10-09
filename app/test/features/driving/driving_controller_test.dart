import 'package:beam_remoteplus/core/platform/hardware_keys.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
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
}
