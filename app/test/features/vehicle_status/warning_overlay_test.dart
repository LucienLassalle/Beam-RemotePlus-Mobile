import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/features/vehicle_status/widgets/warning_overlay.dart';
import 'package:beam_remoteplus/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Telemetry t, int resets) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: WarningOverlay(telemetry: t, resetCount: resets)),
    );

void main() {
  testWidgets('a reset hides the warnings that were on, until they come back', (tester) async {
    const damaged = Telemetry(checkEngine: true);
    await tester.pumpWidget(_app(Telemetry.empty, 0));
    await tester.pumpWidget(_app(damaged, 0));
    expect(find.byIcon(Icons.car_repair), findsWidgets);

    await tester.pumpWidget(_app(damaged, 1)); // vehicle reset from the phone
    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.car_repair), findsNothing);

    await tester.pumpWidget(_app(Telemetry.empty, 1)); // turned off...
    await tester.pumpWidget(_app(damaged, 1)); // ...and on again: shown
    expect(find.byIcon(Icons.car_repair), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
  });
}
