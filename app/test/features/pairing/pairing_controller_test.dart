import 'dart:async';

import 'package:beam_remoteplus/core/network/beamng_connection.dart';
import 'package:beam_remoteplus/core/protocol/mod_protocol.dart';
import 'package:beam_remoteplus/features/pairing/pairing_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeConnection extends BeamngConnection {
  final Object? failure;
  String? code;
  String? host;
  _FakeConnection([this.failure]);

  @override
  Future<void> connect(String code, {String? knownHost, bool display = false}) async {
    this.code = code;
    host = knownHost;
    if (failure != null) throw failure!;
  }
}

void main() {
  test('automatic connection uses the discovered code and host', () async {
    final connection = _FakeConnection();
    final c = PairingController(
      discover: () async => const DiscoveredHost(securityCode: '12345', hostAddress: '10.0.0.2', label: 'PC'),
      newConnection: () => connection,
    );
    expect(await c.autoConnect(), same(connection));
    expect(connection.code, '12345');
    expect(connection.host, '10.0.0.2');
    expect(c.error, isNull);
    expect(c.busy, isFalse);
  });

  test('reports a PC that was not found', () async {
    final c = PairingController(discover: () async => null);
    expect(await c.autoConnect(), isNull);
    expect(c.error, PairingError.notFound);
  });

  test('validates manual codes and QR contents', () async {
    final c = PairingController(newConnection: _FakeConnection.new);
    expect(await c.submitCode('12'), isNull);
    expect(c.error, PairingError.invalidCode);
    expect(await c.onQrScanned('hello'), isNull);
    expect(c.error, PairingError.invalidQr);
    expect(await c.onQrScanned('https://x#54321'), isNotNull);
  });

  test('maps a timeout and other failures', () async {
    final timeout = PairingController(newConnection: () => _FakeConnection(TimeoutException('t')));
    await timeout.submitCode('12345');
    expect(timeout.error, PairingError.timeout);
    final failed = PairingController(newConnection: () => _FakeConnection(StateError('boom')));
    await failed.submitCode('12345');
    expect(failed.error, PairingError.failed);
    expect(failed.errorDetail, contains('boom'));
  });
}
