import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_scope.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/features/settings/settings_sheet.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_driving_view.dart';

void main() {
  late MemorySettingsStore store;
  late SettingsController settings;
  var recalibrated = 0;
  bool? paused;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    store = MemorySettingsStore();
    settings = SettingsController(store);
    recalibrated = 0;
    paused = null;
    await tester.pumpWidget(SettingsScope(
      controller: settings,
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSettingsSheet(
                context,
                readOnly: false,
                onReadOnlyChanged: (v) => paused = v,
                onRecalibrate: () => recalibrated++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('recalibrate and pause come first, then the four tabs', (tester) async {
    await open(tester);
    final recalibrate = tester.getTopLeft(find.text('Recalibrate steering'));
    final displayTab = tester.getTopLeft(find.text('Display'));
    expect(recalibrate.dy, lessThan(displayTab.dy));
    for (final tab in ['Display', 'Gameplay', 'Controls', 'Advanced']) {
      expect(find.text(tab), findsOneWidget);
    }
    await tester.tap(find.text('Recalibrate steering'));
    await tester.tap(find.text('Pause the controls'));
    await tester.pump();
    expect(recalibrated, 1);
    expect(paused, isTrue);
  });

  testWidgets('display tab saves the speed unit on the phone', (tester) async {
    await open(tester);
    expect(find.text('Phone language'), findsOneWidget);
    await tester.tap(find.text('mph'));
    await tester.pumpAndSettle();
    expect(store.values['useKmh'], isFalse);
  });

  testWidgets('display tab: brake, tyre and axle icons can only be hidden with the engine ones', (tester) async {
    await open(tester);
    await tester.drag(find.text('Phone language'), const Offset(0, -900));
    await tester.pumpAndSettle();
    SwitchListTile tile(String title) => tester.widget(find.widgetWithText(SwitchListTile, title));
    expect(tile('Engine, radiator and fuel tank icons').value, isFalse);
    expect(tile('Brake, tyre and axle icons').value, isTrue);
    await tester.tap(find.text('Brake, tyre and axle icons'));
    await tester.pumpAndSettle();
    expect(store.values['damageWheelParts'], isFalse);
    await tester.tap(find.text('Engine, radiator and fuel tank icons'));
    await tester.pumpAndSettle();
    expect(store.values['damageCarParts'], isTrue);
    expect(tile('Brake, tyre and axle icons').value, isTrue);
    expect(tile('Brake, tyre and axle icons').onChanged, isNull);
  });

  testWidgets('gameplay tab: vibrations sub-menu and custom rotation range', (tester) async {
    await open(tester);
    await tester.tap(find.text('Gameplay'));
    await tester.pumpAndSettle();
    expect(find.text('Tilt'), findsOneWidget);

    await tester.tap(find.text('Other…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1080');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(settings.settings.rotationRangeDeg, 1080);
    expect(find.text('1080°'), findsOneWidget);

    await tester.drag(find.text('Steering mode'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vibrations'));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Vibrations'), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kerbs'));
    await tester.pumpAndSettle();
    expect(settings.settings.hapticKerbs, isFalse);
  });

  testWidgets('controls tab disables the horn on the volume button', (tester) async {
    await open(tester);
    await tester.tap(find.text('Controls'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable the horn on the volume button'));
    await tester.pumpAndSettle();
    expect(settings.settings.hornOnVolume, isFalse);
    expect(settings.settings.flashOnVolume, isTrue);
  });
}
