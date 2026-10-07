import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/network/beamng_connection.dart';
import '../../core/network/mod_discovery.dart';
import '../../core/protocol/mod_protocol.dart';
import '../../core/protocol/pairing_code.dart';

enum PairingStatus { idle, searching, connecting }

enum PairingError { notFound, timeout, invalidCode, invalidQr, failed }

/// Logic of the pairing screen: automatic discovery, manual code and QR.
/// Returns a connected [BeamngConnection] for the driving screen.
class PairingController extends ChangeNotifier {
  final Future<DiscoveredHost?> Function() _discover;
  final BeamngConnection Function() _newConnection;

  /// Connect as a display-only second screen (see AppSettings.secondScreen).
  bool secondScreen = false;

  PairingStatus _status = PairingStatus.idle;
  PairingError? _error;
  String? _errorDetail;

  PairingController({
    Future<DiscoveredHost?> Function()? discover,
    BeamngConnection Function()? newConnection,
  })  : _discover = discover ?? ModDiscovery.discover,
        _newConnection = newConnection ?? BeamngConnection.new;

  PairingStatus get status => _status;
  bool get busy => _status != PairingStatus.idle;
  PairingError? get error => _error;
  String? get errorDetail => _errorDetail;

  void _set(PairingStatus status, {PairingError? error, String? detail}) {
    _status = status;
    _error = error;
    _errorDetail = detail;
    notifyListeners();
  }

  Future<BeamngConnection?> autoConnect() async {
    if (busy) return null;
    _set(PairingStatus.searching);
    final host = await _discover();
    if (host == null) {
      _set(PairingStatus.idle, error: PairingError.notFound);
      return null;
    }
    _set(PairingStatus.idle);
    return connect(host.securityCode, knownHost: host.hostAddress);
  }

  Future<BeamngConnection?> submitCode(String text) {
    final code = PairingCode.tryParse(text);
    if (code == null) {
      _set(PairingStatus.idle, error: PairingError.invalidCode);
      return Future.value();
    }
    return connect(code.securityCode);
  }

  Future<BeamngConnection?> onQrScanned(String? raw) {
    final code = raw == null ? null : PairingCode.tryParse(raw);
    if (code == null) {
      _set(PairingStatus.idle, error: PairingError.invalidQr);
      return Future.value();
    }
    return connect(code.securityCode);
  }

  Future<BeamngConnection?> connect(String code, {String? knownHost}) async {
    if (busy) return null;
    _set(PairingStatus.connecting);
    final connection = _newConnection();
    try {
      await connection.connect(code, knownHost: knownHost, display: secondScreen);
      _set(PairingStatus.idle);
      return connection;
    } on TimeoutException {
      connection.dispose();
      _set(PairingStatus.idle, error: PairingError.timeout);
    } catch (e) {
      connection.dispose();
      _set(PairingStatus.idle, error: PairingError.failed, detail: '$e');
    }
    return null;
  }
}
