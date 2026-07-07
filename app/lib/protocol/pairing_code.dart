/// Contenu du QR code affiché par BeamNG.drive
/// (Options > Contrôles > Matériel > Application de contrôle à distance).
///
/// Format vérifié depuis QRCodeScanner.java : `<texte>#<securityCode>`,
/// seule la partie après `#` est utilisée par le protocole.
class PairingCode {
  final String securityCode;

  const PairingCode(this.securityCode);

  static PairingCode? tryParse(String raw) {
    final parts = raw.split('#');
    if (parts.length != 2 || parts[1].isEmpty) {
      return null;
    }
    return PairingCode(parts[1]);
  }
}
