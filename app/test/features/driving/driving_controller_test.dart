import 'package:beam_remoteplus/core/platform/hardware_keys.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/features/driving/driving_controller.dart';
import 'package:beam_remoteplus/themes/control_theme.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';

void main() {
  late FakeLink link;
  late DrivingController controller;
  var shiftPoints = 0;

  setUp(() {
    link = FakeLink();
    shiftPoints = 0;
    controller = DrivingController(link: link, settings: const AppSettings(shiftHaptics: true), onShiftPoint: () => shiftPoints++);
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

  test('volume buttons do nothing when disabled in the settings', () {
    controller.settings = const AppSettings(volumeKeys: false);
    controller.onHardwareKey(HardwareKey.volumeUp, true);
    expect(link.commands, isEmpty);
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

  test('vibrates once on the rising edge of the shift light', () async {
    link.telemetry_.add(const Telemetry(shiftLight: true));
    link.telemetry_.add(const Telemetry(shiftLight: true));
    link.telemetry_.add(const Telemetry(shiftLight: false));
    link.telemetry_.add(const Telemetry(shiftLight: true));
    await Future<void>.delayed(Duration.zero);
    expect(shiftPoints, 2);
    expect(controller.telemetry.shiftLight, isTrue);
  });
}
