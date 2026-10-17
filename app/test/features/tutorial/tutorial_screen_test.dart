import 'dart:async';
import 'dart:math' as math;

import 'package:beam_remoteplus/core/settings/settings_controller.dart';
import 'package:beam_remoteplus/core/settings/settings_scope.dart';
import 'package:beam_remoteplus/core/settings/settings_store.dart';
import 'package:beam_remoteplus/features/driving/widgets/touch_wheel.dart';
import 'package:beam_remoteplus/features/tutorial/tutorial_screen.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../helpers/pump_driving_view.dart' show phoneSize;

void main() {
  late SettingsController settings;
  late StreamController<AccelerometerEvent> tilt;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = phoneSize * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    tilt = StreamController<AccelerometerEvent>.broadcast();
    addTearDown(tilt.close);
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
            onPressed: () => showTutorial(context, accelerometer: tilt.stream),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    expect(settings.settings.tutorialSeen, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }

  testWidgets('goes through the six pages and is not shown again', (tester) async {
    await open(tester);
    expect(find.text('Drive with your phone'), findsOneWidget);
    for (final title in ['Steering', 'Pedals', 'Volume buttons', 'Buttons to hold', 'Settings']) {
      await next(tester);
      expect(find.text(title), findsWidgets);
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

  testWidgets('the wheel turns with the phone', (tester) async {
    await open(tester);
    await next(tester);
    double wheelAngle() => (tester.widget<CustomPaint>(
          find.byWidgetPredicate((w) => w is CustomPaint && w.painter is SteeringWheelPainter),
        ).painter! as SteeringWheelPainter)
        .angleDeg;
    void roll(double deg) {
      final r = deg * math.pi / 180;
      tilt.add(AccelerometerEvent(0, 9.81 * math.sin(r), 9.81 * math.cos(r), DateTime.now()));
    }

    for (var i = 0; i < 25; i++) {
      roll(0);
    }
    await tester.pump();
    expect(wheelAngle(), 0);
    for (var i = 0; i < 10; i++) {
      roll(40);
    }
    await tester.pump();
    await tester.pump();
    expect(wheelAngle().abs(), greaterThan(10));
  });

  testWidgets('the reset button works once held, not on a tap', (tester) async {
    await open(tester);
    for (var i = 0; i < 4; i++) {
      await next(tester);
    }
    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Vehicle reset!'), findsNothing);
    final hold = await tester.startGesture(tester.getCenter(find.byIcon(Icons.restart_alt)));
    await tester.pump(); // the ring starts here
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Vehicle reset!'), findsOneWidget);
    await hold.up();
  });
}
