import 'package:beam_remoteplus/features/optional_mods/optional_mods.dart';
import 'package:beam_remoteplus/features/optional_mods/optional_mods_sheet.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, {Map<String, String>? states}) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            TextButton(onPressed: () => showOptionalModsSheet(context, states: states), child: const Text('open')),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every supported mod and what it adds', (tester) async {
    await _open(tester);
    for (final name in ['Tyre Thermals and Wear (Luuk or Redux)', 'Carbonworks F4 by LucasBE', 'CF26 (add-on of the F4)', 'FR17']) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('DRS button (F4 theme)'), findsOneWidget);
    // Not connected: no state.
    expect(find.text('Enabled'), findsNothing);
    expect(find.text('Not installed'), findsNothing);
  });

  testWidgets('shows the state of each mod in the game', (tester) async {
    await _open(tester, states: {'fr17': 'enabled', 'tyreThermals': 'enabled', 'cf26': 'disabled', 'f4': 'missing'});
    expect(find.text('Enabled'), findsNWidgets(2));
    expect(find.text('Installed, disabled'), findsOneWidget);
    expect(find.text('Not installed'), findsOneWidget);
  });

  test('reads the states sent by the mod', () {
    expect(OptionalModState.tryParse('disabled'), OptionalModState.disabled);
    expect(OptionalModState.tryParse('weird'), isNull);
    expect(OptionalModState.tryParse(null), isNull);
  });
}
