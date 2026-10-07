import 'package:beam_remoteplus/core/settings/app_settings.dart';
import 'package:beam_remoteplus/features/driving/driving_controller.dart';
import 'package:beam_remoteplus/features/driving/driving_view.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:beam_remoteplus/themes/control_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_link.dart';

/// Landscape phone, 900x420 logical pixels.
const phoneSize = Size(900, 420);

Future<DrivingController> pumpDrivingView(
  WidgetTester tester, {
  required ControlTheme theme,
  required FakeLink link,
  AppSettings settings = const AppSettings(),
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = phoneSize * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final controller = DrivingController(link: link, settings: settings, onShiftPoint: () {});
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData.dark(),
    home: Scaffold(
      body: DrivingView(
        controller: controller,
        settings: settings,
        theme: theme,
        hostButtons: const SizedBox(width: 96, height: 48),
        onRecovered: () {},
        accelerometer: const Stream.empty(),
      ),
    ),
  ));
  return controller;
}
