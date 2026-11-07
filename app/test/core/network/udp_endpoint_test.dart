import 'dart:io';

import 'package:beam_remoteplus/core/network/udp_endpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tells when the system closed the socket after a failed send', () async {
    final endpoint = await IoUdpEndpoint.bind(0);
    addTearDown(endpoint.close);
    expect(endpoint.closed, isFalse);
    // Refused by the system (an IPv6 address on an IPv4 socket), as a send
    // is while the phone has no network: Dart then closes the socket.
    endpoint.send([1], InternetAddress.loopbackIPv6, 4446);
    await pumpEventQueue();
    expect(endpoint.closed, isTrue);
  });

  test('receives what is sent to its port', () async {
    const port = 47447;
    final endpoint = await IoUdpEndpoint.bind(port);
    final sender = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(endpoint.close);
    addTearDown(sender.close);
    final received = endpoint.datagrams.first;
    sender.send([7], InternetAddress.loopbackIPv4, port);
    expect((await received).data, [7]);
  });
}
