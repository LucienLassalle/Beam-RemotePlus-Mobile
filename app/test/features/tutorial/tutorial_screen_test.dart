import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_scope.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/features/tutorial/tutorial_screen.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_driving_view.dart' show phoneSize;

void main() {
  late SettingsController settings;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    settings = SettingsController(MemorySettingsStore());
    await settings.load();
    await tester.pumpWidget(SettingsScope(
      controller: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTutorial(context, accelerometer: const Stream.empty()),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    expect(settings.settings.tutorialSeen, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('goes through the four pages and is not shown again', (tester) async {
    await open(tester);
    expect(find.text('Drive with your phone'), findsOneWidget);
    for (final title in ['Steering', 'Pedals', 'Buttons']) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    await tester.tap(find.text("Let's drive"));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(settings.settings.tutorialSeen, isTrue);
  });

  testWidgets('can be skipped, which also counts as seen', (tester) async {
    await open(tester);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(settings.settings.tutorialSeen, isTrue);
  });
}
