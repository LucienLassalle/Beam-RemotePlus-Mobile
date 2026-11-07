import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../debug/debug_log.dart';
import '../protocol/native_protocol.dart';
import 'udp_endpoint.dart';

/// BeamNG.drive's own remote control (port 4444, no mod needed): finds the
/// PC with the pairing code, then gives steering and pedals until the mod
/// answers.
class NativeChannel {
  final UdpBinder _bind;
  UdpEndpoint? _control;
  InternetAddress? _host;
  int _sequence = 0;
  bool _reopening = false;
  Timer? _reopenTimer;

  /// A socket closed by the system is replaced at most this often: the
  /// controls go 20 times a second, and each send fails while the phone has
  /// no network.
  static const reopenDelay = Duration(milliseconds: 500);

  NativeChannel(this._bind);

  /// Sends the handshake to every target until the game answers with
  /// [code]; returns the PC address. Throws a [TimeoutException] when no
  /// game answers.
  Future<InternetAddress> pair(String code, String deviceName, List<String> targets) async {
    close();
    final handshake = await _bind(NativeProtocol.clientPort);
    try {
      final host = await _handshake(handshake, code, deviceName, targets);
      _control = await _bind(0);
      _host = host;
      return host;
    } finally {
      handshake.close();
    }
  }

  Future<InternetAddress> _handshake(UdpEndpoint endpoint, String code, String deviceName, List<String> targets) async {
    final expected = NativeProtocol.expectedAnswer(code);
    final answer = Completer<InternetAddress>();
    final answers = endpoint.datagrams.listen((dg) {
      if (answer.isCompleted) return;
      final msg = utf8.decode(dg.data, allowMalformed: true);
      DebugLog.log('handshake: "$msg" from ${dg.address.address}');
      if (msg == expected) answer.complete(dg.address);
    });

    final payload = utf8.encode(NativeProtocol.handshake(deviceName, code));
    var attempts = 0;
    final retry = Timer.periodic(const Duration(milliseconds: NativeProtocol.discoveryRetryMs), (t) {
      if (answer.isCompleted || ++attempts > NativeProtocol.discoveryMaxRetries) {
        t.cancel();
        return;
      }
      for (final target in targets) {
        try {
          endpoint.send(payload, InternetAddress(target), NativeProtocol.hostPort);
        } catch (e) {
          DebugLog.log('handshake: send to $target failed ($e)');
        }
      }
    });
    try {
      return await answer.future.timeout(
        const Duration(milliseconds: NativeProtocol.discoveryRetryMs * (NativeProtocol.discoveryMaxRetries + 2)),
      );
    } finally {
      retry.cancel();
      unawaited(answers.cancel());
    }
  }

  /// The PC changed address (found again by the mod channel).
  void retarget(InternetAddress host) {
    if (_control != null) _host = host;
  }

  /// One control packet to the paired game (ignored before [pair]).
  void sendControls({required double steering, required double throttle, required double brake}) {
    final control = _control;
    final host = _host;
    if (control == null || host == null) return;
    if (control.closed) {
      _reopenTimer ??= Timer(reopenDelay, () {
        _reopenTimer = null;
        unawaited(_replace(control));
      });
      return;
    }
    final packet = NativeControlPacket(steering: steering, throttle: throttle, brake: brake, sequenceId: _sequence);
    _sequence = (_sequence + 1) % 128;
    control.send(packet.toBytes(), host, NativeProtocol.hostPort);
  }

  /// Binds a new socket in place of the current one (see
  /// ModChannel.renewSocket).
  Future<void> renewSocket() async {
    final old = _control;
    if (old != null) await _replace(old);
  }

  // Closed by the system after a failed send (no network for a moment), or
  // renewed: the controls go through a new socket.
  Future<void> _replace(UdpEndpoint old) async {
    if (_reopening) return;
    _reopening = true;
    old.close();
    try {
      final control = await _bind(0);
      if (_control != old) return control.close(); // the channel was closed meanwhile
      _control = control;
      DebugLog.log('native channel: new socket');
    } catch (e) {
      DebugLog.log('native channel: cannot bind a new socket ($e)');
    } finally {
      _reopening = false;
    }
  }

  void close() {
    _reopenTimer?.cancel();
    _reopenTimer = null;
    _control?.close();
    _control = null;
    _host = null;
  }
}
