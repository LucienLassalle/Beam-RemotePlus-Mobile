import 'package:beam_remoteplus/core/protocol/pairing_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads the code after # (BeamNG < 0.39 QR)', () {
    expect(PairingCode.tryParse('beamng#54688')!.securityCode, '54688');
  });
  test('reads the code of the Play Store URL (BeamNG >= 0.39 QR)', () {
    expect(PairingCode.tryParse('https://play.google.com/store/apps/details?id=com.beamng.remotecontrol#54688')!.securityCode, '54688');
  });
  test('accepts a typed code and digits inside text', () {
    expect(PairingCode.tryParse(' 12345 ')!.securityCode, '12345');
    expect(PairingCode.tryParse('code: 98765.')!.securityCode, '98765');
  });
  test('rejects content without a usable code', () {
    expect(PairingCode.tryParse(''), isNull);
    expect(PairingCode.tryParse('abc#12'), isNull);
  });
}
