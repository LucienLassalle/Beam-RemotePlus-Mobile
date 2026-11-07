import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:beam_remoteplus/core/network/udp_endpoint.dart';

/// A datagram the phone sent.
class Sent {
  final List<int> data;
  final InternetAddress host;
  final int port;
  const Sent(this.data, this.host, this.port);

  String get text => utf8.decode(data, allowMalformed: true);

  @override
  String toString() => '$port <- $text';
}

/// In-memory network: [bind] replaces [IoUdpEndpoint.bind], every datagram
/// the phone sends lands in [sent], and tests deliver answers with
/// [FakeEndpoint.receive].
class FakeNetwork {
  /// Endpoints by local port, the last one bound on each port.
  final Map<int, FakeEndpoint> endpoints = {};
  final List<Sent> sent = [];

  /// Binding these ports fails (port taken by another app).
  final Set<int> busyPorts = {};

  int _nextFreePort = 50000;

  Future<UdpEndpoint> bind(int port) async {
    if (busyPorts.contains(port)) throw const SocketException('address already in use');
    final local = port == 0 ? _nextFreePort++ : port;
    return endpoints[local] = FakeEndpoint(this, local);
  }

  /// What was sent to [port] of the PC, as text.
  List<String> sentTo(int port) => [for (final s in sent) if (s.port == port) s.text];

  /// Binary datagrams sent to [port] of the PC.
  List<List<int>> bytesTo(int port) => [for (final s in sent) if (s.port == port) s.data];
}

class FakeEndpoint implements UdpEndpoint {
  final FakeNetwork _network;
  final int port;
  final _incoming = StreamController<Datagram>();
  bool closed = false;

  FakeEndpoint(this._network, this.port);

  @override
  Stream<Datagram> get datagrams => _incoming.stream;

  @override
  void send(List<int> data, InternetAddress host, int port) => _network.sent.add(Sent(data, host, port));

  /// Delivers [text] (or [bytes]) from [from]:[fromPort] to this endpoint.
  void receive(String text, {required String from, int fromPort = 4446}) =>
      receiveBytes(utf8.encode(text), from: from, fromPort: fromPort);

  void receiveBytes(List<int> bytes, {required String from, int fromPort = 4446}) {
    if (closed) return;
    _incoming.add(Datagram(Uint8List.fromList(bytes), InternetAddress(from), fromPort));
  }

  @override
  void close() {
    closed = true;
    unawaited(_incoming.close());
  }
}
