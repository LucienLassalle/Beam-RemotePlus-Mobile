import 'dart:async';
import 'dart:io';

/// One UDP socket of the phone: what the connection needs of it, so tests
/// can replace the network (see test/helpers/fake_network.dart).
abstract class UdpEndpoint {
  /// Datagrams received. Listened to once.
  Stream<Datagram> get datagrams;

  /// Sends [data] to [host]:[port].
  void send(List<int> data, InternetAddress host, int port);

  void close();
}

/// Opens a [UdpEndpoint] on [port] of every IPv4 interface (0: any free
/// port). Broadcasts are allowed.
typedef UdpBinder = Future<UdpEndpoint> Function(int port);

/// A [RawDatagramSocket] bound to anyIPv4: in hotspot mode some phones
/// report the mobile-data IP as "Wi-Fi IP", and binding to it would silently
/// drop every answer arriving on the real Wi-Fi interface.
class IoUdpEndpoint implements UdpEndpoint {
  final RawDatagramSocket _socket;

  IoUdpEndpoint._(this._socket);

  /// Fixed ports are bound with reuseAddress: a previous session may still
  /// hold them for a moment.
  static Future<UdpEndpoint> bind(int port) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reuseAddress: port != 0);
    socket.broadcastEnabled = true;
    return IoUdpEndpoint._(socket);
  }

  @override
  late final Stream<Datagram> datagrams = _socket
      .where((event) => event == RawSocketEvent.read)
      .map((_) => _socket.receive())
      .where((dg) => dg != null)
      .cast<Datagram>();

  @override
  void send(List<int> data, InternetAddress host, int port) => _socket.send(data, host, port);

  @override
  void close() => _socket.close();
}
