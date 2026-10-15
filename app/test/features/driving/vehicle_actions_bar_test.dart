import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:beam_remoteplus/themes/theme_registry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';
import '../../helpers/pump_driving_view.dart';

void main() {
  testWidgets('one headlights button shows off, dipped and main beam, and cycles them', (tester) async {
    final link = FakeLink();
    addTearDown(link.dispose);
    await pumpDrivingView(tester, theme: themeByName('Road'), link: link);

    Future<void> lights({required bool low, required bool high}) async {
      link.telemetry_.add(Telemetry(lowBeam: low, highBeam: high));
      await tester.pump(); // delivers the frame (stream microtask)
      await tester.pump(); // rebuilds with it
    }

    await lights(low: false, high: false);
    expect(find.byTooltip('Headlights off (tap: dipped beam)'), findsOneWidget);
    await lights(low: true, high: false);
    expect(find.byTooltip('Dipped beam (tap: main beam)'), findsOneWidget);
    await lights(low: true, high: true);
    expect(find.byTooltip('Main beam (tap: off)'), findsOneWidget);

    await tester.tap(find.byTooltip('Main beam (tap: off)'));
    expect(link.commands, ['lights']);
  });
}
