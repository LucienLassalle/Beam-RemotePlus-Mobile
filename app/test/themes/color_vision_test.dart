import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/themes/kit/kit.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';

void main() {
  test('shift lights: blue and orange instead of green and red', () {
    const lights = ShiftLights(rpm: 7000, maxRpm: 7000, count: 10);
    expect(lights.colorFor(0), Colors.greenAccent);
    expect(lights.colorFor(5), Colors.redAccent);
    expect(lights.colorFor(0, colorBlind: true), ColorVision.throttle);
    expect(lights.colorFor(5, colorBlind: true), ColorVision.brake);
  });

  test('damage view: blue for what is fine', () {
    expect(DamageView.partColor(PartState.ok), DamageView.okColor);
    expect(DamageView.partColor(PartState.ok, colorBlind: true), ColorVision.fine);
    expect(DamageView.brakeColor(100, colorBlind: true), ColorVision.fine);
    expect(DamageView.beamColor(1, colorBlind: true).b, greaterThan(DamageView.beamColor(1, colorBlind: true).g));
  });

  testWidgets('the driving screen tells the kit widgets', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Default'), link: link, settings: const AppSettings(colorBlind: true));
    final context = tester.element(find.byType(ShiftLights));
    expect(ColorVision.colorBlindOf(context), isTrue);
  });
}
