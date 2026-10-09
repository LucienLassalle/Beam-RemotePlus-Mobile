import 'package:beam_remoteplus/themes/kit/kit.dart';
import 'package:beam_remoteplus/themes/kit/sample_telemetry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample_skeleton.dart';

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

  const electric = Telemetry(powertrain: 'electric', rpm: 3000, fuel: 0.4, engineAt: 0.8, shafts: ['wheelaxleRL', 'wheelaxleRR']);

  for (final (name, telemetry) in [
    ('sample', sampleTelemetry),
    ('wrecked', wrecked),
    ('electric', electric),
    ('no data', Telemetry.empty),
  ]) {
    testWidgets('without the vehicle structure, draws the $name car with the 0.0.3 schematic', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(height: 160, child: DamageView(telemetry: telemetry, pressureUnit: PressureUnit.psi)),
        ),
      ));
      expect(tester.takeException(), isNull);
      expect(find.byType(SimpleDamageView), findsOneWidget);
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

  group('with the vehicle skeleton', () {
    final car = sampleSkeleton();
    final truck = sampleSkeleton(id: 'truck', width: 2.5, length: 9, axles: const [3.2, -2.2, -3.6], engine: const Offset(0, 3.4));

    for (final (name, skeleton) in [('car', car), ('truck', truck)]) {
      testWidgets('draws the $name structure and its damage without error', (tester) async {
        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              height: 200,
              child: DamageView(telemetry: wrecked, skeleton: skeleton, skeletonLevels: skeleton.levels(sampleDamage(skeleton))),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('draws the bare structure, without any pictogram', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            height: 200,
            child: DamageView(telemetry: wrecked, skeleton: car, showCarParts: false, showWheelParts: false),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });

    test('parts go where they really are, front at the top', () {
      final l = DamageLayout.of(const Telemetry(), truck);
      expect(l.tyres.length, 6);
      expect(l.tyres['FL']!.center.dy, lessThan(l.tyres['R1L']!.center.dy));
      expect(l.isLeft('FL'), isTrue);
      expect(l.isLeft('R2R'), isFalse);
      expect(l.engine.dy, lessThan(l.frontAxleY + 5));
      expect(l.rearAxleY, closeTo((l.tyres['R1L']!.center.dy + l.tyres['R2L']!.center.dy) / 2, 0.01));
      // The truck fills the height, keeping its proportions.
      expect(l.tailY - l.noseY, closeTo(194, 1));
      expect(l.rearEngine, isFalse);
    });

    testWidgets('simplified damage keeps the 0.0.3 schematic, structure known or not', (tester) async {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(height: 200, child: DamageView(telemetry: wrecked, skeleton: car, simplified: true))),
      ));
      expect(find.byType(SimpleDamageView), findsOneWidget);
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: SizedBox(height: 200, child: DamageView(telemetry: wrecked, skeleton: car))),
      ));
      expect(find.byType(SimpleDamageView), findsNothing);
      expect(tester.getSize(find.byType(DamageView)).width, closeTo(200 * DamageView.aspectRatio, 0.5));
    });

    test('beam colours go from green to red', () {
      expect(DamageView.beamColor(9), const Color(0xFFFF0000));
      expect(DamageView.beamColor(1).g, greaterThan(DamageView.beamColor(1).r));
    });
  });
}
