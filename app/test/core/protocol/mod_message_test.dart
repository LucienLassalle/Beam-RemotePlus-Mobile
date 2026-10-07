import 'dart:convert';
import 'dart:typed_data';

import 'package:beam_remoteplus/core/protocol/mod_message.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _json(Object value) => Uint8List.fromList(utf8.encode(jsonEncode(value)));

void main() {
  test('decodes v2 telemetry', () {
    final m = ModMessage.decode(_json({'type': 'telemetry', 'rpm': 1000}), 2);
    expect((m! as TelemetryMessage).telemetry.rpm, 1000);
  });

  test('decodes acks', () {
    final m = ModMessage.decode(_json({'type': 'ack', 'cmd': 'horn|1', 'ok': false, 'error': 'no_vehicle'}), 2)! as AckMessage;
    expect(m.command, 'horn|1');
    expect(m.ok, isFalse);
    expect(m.error, 'no_vehicle');
  });

  test('decodes session messages', () {
    final m = ModMessage.decode(_json({'type': 'session', 'modVersion': '2.0.0', 'player': 1, 'commands': ['horn', 3]}), 2)!
        as SessionMessage;
    expect(m.modVersion, '2.0.0');
    expect(m.player, 1);
    expect(m.commands, ['horn']);
  });

  test('ignores unknown types, garbage and non-objects (forward compatible)', () {
    expect(ModMessage.decode(_json({'type': 'future'}), 2), isNull);
    expect(ModMessage.decode(Uint8List.fromList(utf8.encode('{broken')), 2), isNull);
    expect(ModMessage.decode(_json([1, 2]), 2), isNull);
    expect(ModMessage.decode(Uint8List(0), 2), isNull);
  });

  test('v1 only understands the 36-byte binary telemetry', () {
    expect(ModMessage.decode(Uint8List(36), 1), isA<TelemetryMessage>());
    expect(ModMessage.decode(_json({'type': 'telemetry'}), 1), isNull);
  });
}
