import 'package:flutter_test/flutter_test.dart';

import 'package:beam_remoteplus/main.dart';

void main() {
  testWidgets('App démarre sur l\'écran de pairing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const BeamngRemotePlusApp());
    expect(find.text('BeamNG RemotePlus'), findsOneWidget);
  });
}
