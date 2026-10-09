@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_scope.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/features/settings/settings_sheet.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:beam_remoteplus/themes/kit/kit.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';
import '../helpers/sample_skeleton.dart';

/// Renders every theme with sample telemetry into test/screenshots/goldens/
/// so theme authors and reviewers can SEE a theme without a phone:
///   scripts/flutter.sh screenshots
/// Not a regression test (fonts differ between machines): excluded from CI.
void main() {
  setUpAll(_loadFonts);

  testWidgets('second screen and vehicle panel previews', (tester) async {
    for (final (name, settings) in [
      ('Second screen', const AppSettings(themeName: 'Road', secondScreen: true)),
      ('Vehicle panel', const AppSettings(showVehiclePanel: true)),
    ]) {
      final link = FakeLink();
      await pumpDrivingView(tester, theme: themeByName(settings.themeName), link: link, settings: settings);
      link.telemetry_.add(sampleTelemetry);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // let the warning pop fade
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      link.dispose();
    }
  });

  testWidgets('damage schematic', (tester) async {
    tester.view.physicalSize = const Size(900, 420) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const wrecked = Telemetry(
      rpm: 900,
      engineAt: 0.72,
      waterTemp: 121,
      fuel: 0.3,
      fuelLeak: true,
      engineDamage: ['radiatorLeak', 'engineLockedUp'],
      bodyDamage: {'RL': 0.8, 'RR': 0.4, 'MR': 0.1},
      shafts: ['wheelaxleRL', 'wheelaxleRR'],
      brokenParts: ['wheelaxleRR'],
      flatTires: ['RR'],
      brokenWheels: ['FL'],
      brokenBrakes: ['RL'],
      tirePressures: {'FR': 180, 'RL': 120, 'RR': 0},
      tirePressuresNominal: {'FR': 180, 'RL': 180, 'RR': 180},
      brakeTemps: {'FR': 90, 'RL': 900, 'RR': 120},
    );
    const electric = Telemetry(
      powertrain: 'electric',
      rpm: 4000,
      engineAt: 0.78,
      fuel: 0.55,
      shafts: ['wheelaxleRL', 'wheelaxleRR'],
      tirePressures: {'FL': 250, 'FR': 250, 'RL': 260, 'RR': 260},
      tirePressuresNominal: {'FL': 250, 'FR': 250, 'RL': 260, 'RR': 260},
      brakeTemps: {'FL': 60, 'FR': 60, 'RL': 50, 'RR': 50},
      bodyDamage: {'FR': 0.2},
    );
    await tester.pumpWidget(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          SizedBox(height: 300, child: DamageView(telemetry: sampleTelemetry)),
          SizedBox(height: 300, child: DamageView(telemetry: wrecked, pressureUnit: PressureUnit.psi)),
          SizedBox(height: 300, child: DamageView(telemetry: electric)),
        ]),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Damage schematic.png'));

    final car = sampleSkeleton();
    final truck = sampleSkeleton(id: 'truck', width: 2.5, length: 9, axles: const [3.2, -2.2, -3.6], engine: const Offset(0, 3.4));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          SizedBox(height: 300, child: DamageView(telemetry: sampleTelemetry, skeleton: car, skeletonLevels: car.levels(''))),
          SizedBox(
            height: 300,
            child: DamageView(telemetry: wrecked, skeleton: car, skeletonLevels: car.levels(sampleDamage(car))),
          ),
          SizedBox(
            height: 300,
            child: DamageView(
              telemetry: const Telemetry(rpm: 1200, fuel: 0.6, waterTemp: 90, shafts: ['driveshaft', 'wheelaxleR1L', 'wheelaxleR1R']),
              skeleton: truck,
              skeletonLevels: truck.levels(sampleDamage(truck, y: 3.5, x: 2)),
            ),
          ),
        ]),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Damage skeleton.png'));
  });

  testWidgets('settings previews', (tester) async {
    tester.view.physicalSize = phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final settings = SettingsController(MemorySettingsStore());
    await tester.pumpWidget(SettingsScope(
      controller: settings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('fr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent, brightness: Brightness.dark),
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsSheet(context, readOnly: false, onReadOnlyChanged: (_) {}, onRecalibrate: () {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Settings - display.png'));
    await tester.ensureVisible(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>).last);
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Settings - themes.png'));
    await tester.tap(find.text('Road').last); // picks a theme and closes the menu
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jouabilité'));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/Settings - gameplay.png'));
  });

  for (final theme in availableThemes) {
    testWidgets('${theme.name} preview', (tester) async {
      final link = FakeLink();
      addTearDown(link.dispose);
      await pumpDrivingView(tester, theme: theme, link: link, settings: const AppSettings(debugMode: false));
      link.telemetry_.add(sampleTelemetry);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3)); // let the warning pop fade
      await tester.pump();
      final pressed = await tester.startGesture(const Offset(700, 140)); // show the throttle feedback
      await tester.pump();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/${theme.name}.png'));
      await pressed.up();
    });
  }
}

/// Uses real fonts when the Flutter SDK provides them (otherwise text renders
/// as boxes, layout stays readable).
Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter';
  final fonts = Directory('$root/bin/cache/artifacts/material_fonts');
  if (!fonts.existsSync()) return;
  final roboto = FontLoader('Roboto');
  final icons = FontLoader('MaterialIcons');
  for (final f in fonts.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    final data = Future.value(ByteData.sublistView(f.readAsBytesSync()));
    if (name.startsWith('Roboto')) roboto.addFont(data);
    if (name.startsWith('MaterialIcons')) icons.addFont(data);
  }
  await roboto.load();
  await icons.load();
}
