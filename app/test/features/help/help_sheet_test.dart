import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_scope.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/features/help/help_sheet.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (locale, contributions) in [('en', 'contributions are welcome'), ('fr', 'contributions sont les bienvenues')]) {
    testWidgets('help links to both GitHub repositories ($locale)', (tester) async {
      await tester.pumpWidget(SettingsScope(
        controller: SettingsController(MemorySettingsStore()),
        child: MaterialApp(
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showHelpSheet(context), child: const Text('open')),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining(contributions), findsOneWidget);
      expect(find.byType(ActionChip), findsNWidgets(2));
      final urls = tester.widgetList<ActionChip>(find.byType(ActionChip)).map((c) => c.tooltip);
      expect(urls, [appRepositoryUrl, modRepositoryUrl]);
    });
  }
}
