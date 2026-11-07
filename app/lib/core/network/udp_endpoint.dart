import 'dart:async';
import 'dart:io';

import '../debug/debug_log.dart';

/// One UDP socket of the phone: what the connection needs of it, so tests
/// can replace the network (see test/helpers/fake_network.dart).
abstract class UdpEndpoint {
  /// Datagrams received. Listened to once.
  Stream<Datagram> get datagrams;

  /// Sends [data] to [host]:[port] (nothing once [closed]).
  void send(List<int> data, InternetAddress host, int port);

  /// Closed by [close], or by the system: a dead endpoint never comes back,
  /// a new one has to be bound.
  bool get closed;

  void close();
}

/// Opens a [UdpEndpoint] on [port] of every IPv4 interface (0: any free
/// port). Broadcasts are allowed.
typedef UdpBinder = Future<UdpEndpoint> Function(int port);

/// A [RawDatagramSocket] bound to anyIPv4: in hotspot mode some phones
/// report the mobile-data IP as "Wi-Fi IP", and binding to it would silently
/// drop every answer arriving on the real Wi-Fi interface.
///
/// Dart closes a socket for good on its first error, and a send failing
/// while the phone has no network ("Network is unreachable": Wi-Fi switched
/// off or lost) is one: the socket then drops every later send without a
/// word. [closed] tells it, so the owner binds a new one.
class IoUdpEndpoint implements UdpEndpoint {
  final RawDatagramSocket _socket;
  final _datagrams = StreamController<Datagram>();
  bool _closed = false;

  IoUdpEndpoint._(this._socket) {
    _socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final dg = _socket.receive();
        if (dg != null && !_datagrams.isClosed) _datagrams.add(dg);
      },
      onError: (Object e) => DebugLog.log('udp: socket closed by the system ($e)'),
      onDone: _markClosed,
    );
  }

  /// Fixed ports are bound with reuseAddress: a previous session may still
  /// hold them for a moment.
  static Future<UdpEndpoint> bind(int port) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: port != 0);
    socket.broadcastEnabled = true;
    return IoUdpEndpoint._(socket);
  }

  void _markClosed() {
    _closed = true;
    unawaited(_datagrams.close());
  }

  @override
  Stream<Datagram> get datagrams => _datagrams.stream;

  @override
  bool get closed => _closed;

  @override
  void send(List<int> data, InternetAddress host, int port) {
    if (!_closed) _socket.send(data, host, port);
  }

  @override
  void close() {
    _socket.close();
    _markClosed();
  }
}
