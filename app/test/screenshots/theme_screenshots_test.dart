@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_link.dart';
import '../helpers/pump_driving_view.dart';

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
