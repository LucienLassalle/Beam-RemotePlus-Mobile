import 'package:beam_remoteplus/core/debug/debug_monitor.dart';
import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:beam_remoteplus/core/protocol/telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_link.dart';

void main() {
  test('lists the expected fields the vehicle did not send', () {
    expect(missingTelemetryFields(null), Telemetry.expectedFields);
    final t = Telemetry.fromJson({for (final f in Telemetry.expectedFields) f: 1}..remove('oilTemp'));
    expect(missingTelemetryFields(t), ['oilTemp']);
  });

  test('counts telemetry frames of the last second and journals acks', () async {
    var now = DateTime(2026);
    final link = FakeLink();
    final monitor = DebugMonitor(link, now: () => now);
    for (var i = 0; i < 5; i++) {
      link.telemetry_.add(Telemetry.empty);
    }
    link.events_.add(const AckMessage(command: 'horn|1', ok: false, error: 'no_vehicle'));
    link.events_.add(const SessionMessage(modVersion: '2.0.0'));
    await Future<void>.delayed(Duration.zero);
    expect(monitor.telemetryRate, 5);
    expect(monitor.journal.single.error, 'no_vehicle');
    expect(monitor.modVersion, '2.0.0');
    now = now.add(const Duration(seconds: 2));
    expect(monitor.telemetryRate, 0);
    monitor.dispose();
    link.dispose();
  });

  test('keeps only the last results', () async {
    final link = FakeLink();
    final monitor = DebugMonitor(link);
    for (var i = 0; i < DebugMonitor.journalSize + 3; i++) {
      link.events_.add(AckMessage(command: 'c$i', ok: true));
    }
    await Future<void>.delayed(Duration.zero);
    expect(monitor.journal.length, DebugMonitor.journalSize);
    expect(monitor.journal.first.command, 'c${DebugMonitor.journalSize + 2}');
    monitor.dispose();
    link.dispose();
  });
}
