import 'package:beam_remoteplus/themes/kit/kit.dart';
import 'package:beam_remoteplus/themes/kit/sample_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const wrecked = Telemetry(
    rpm: 0,
    engineAt: 0.8,
    fuelLeak: true,
    engineDamage: ['radiatorLeak', 'engineLockedUp'],
    shafts: ['driveshaft', 'wheelaxleRL', 'wheelaxleRR'],
    brokenParts: ['driveshaft', 'wheelaxleRR'],
    flatTires: ['RR'],
    brokenWheels: ['FL'],
    brokenBrakes: ['RL'],
    hotBrakes: ['FR'],
  );

  for (final (name, telemetry) in [('sample', sampleTelemetry), ('wrecked', wrecked), ('no data', Telemetry.empty)]) {
    testWidgets('draws the $name car without error', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(height: 160, child: DamageView(telemetry: telemetry, pressureUnit: PressureUnit.psi)),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(DamageView)).width, closeTo(160 * DamageView.aspectRatio, 0.5));
    });
  }

  test('part states', () {
    expect(DamageView.engineState(wrecked), PartState.broken);
    expect(DamageView.radiatorState(wrecked), PartState.broken);
    expect(DamageView.fuelTankState(wrecked), PartState.broken);
    expect(DamageView.fuelTankState(const Telemetry(fuel: 0.05)), PartState.warning);
    expect(DamageView.fuelTankState(Telemetry.empty), PartState.unknown);
    expect(DamageView.engineState(const Telemetry(engineDamage: ['exhaustBroken'])), PartState.warning);
    expect(DamageView.brakeColor(900), DamageView.brokenColor);
    expect(DamageView.brakeColor(100), DamageView.okColor);
  });
}
