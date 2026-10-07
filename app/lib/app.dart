import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/settings/settings_controller.dart';
import 'core/settings/settings_scope.dart';
import 'features/pairing/pairing_screen.dart';
import 'l10n/generated/app_localizations.dart';

class BeamRemotePlusApp extends StatelessWidget {
  final SettingsController settings;
  final Widget? home;

  const BeamRemotePlusApp({super.key, required this.settings, this.home});

  @override
  Widget build(BuildContext context) {
    return SettingsScope(
      controller: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final code = settings.settings.localeCode;
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            // null = follow the phone language, falling back to English for
            // languages without translation.
            locale: code == null ? null : Locale(code),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent, brightness: Brightness.dark),
              useMaterial3: true,
            ),
            home: home ?? const PairingScreen(),
          );
        },
      ),
    );
  }
}
