import 'package:beam_remoteplus/core/network/broadcast.dart';
import 'package:beam_remoteplus/core/platform/device_name.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('directedBroadcast', () {
    test('computes the subnet broadcast', () {
      expect(directedBroadcast('192.168.43.1', 24), '192.168.43.255');
      expect(directedBroadcast('10.0.5.7', 16), '10.0.255.255');
      expect(directedBroadcast('172.16.0.1', 32), '172.16.0.1');
    });

    test('rejects malformed input', () {
      expect(directedBroadcast('192.168.1', 24), isNull);
      expect(directedBroadcast('300.1.1.1', 24), isNull);
      expect(directedBroadcast('192.168.1.1', 33), isNull);
    });
  });

  group('formatDeviceName', () {
    test('avoids repeating the manufacturer', () {
      expect(formatDeviceName('samsung', 'SM-F946B'), 'Samsung SM-F946B');
      expect(formatDeviceName('Google', 'Google Pixel 8'), 'Google Pixel 8');
      expect(formatDeviceName('xiaomi', 'xiaomi 13'), 'Xiaomi 13');
    });
  });
}
