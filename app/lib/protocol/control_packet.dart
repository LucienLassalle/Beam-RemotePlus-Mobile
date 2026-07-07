import 'dart:typed_data';

/// Paquet de contrôle envoyé par le téléphone au jeu (port 4444).
///
/// Format vérifié depuis Sendpacket.java : 16 octets, 4 floats big-endian.
/// L'ancienne app n'envoyait jamais [throttle]/[brake] qu'à 0.0 ou 1.0 ;
/// le champ étant un float, BeamNG.drive accepte en pratique des valeurs
/// intermédiaires, ce qui permet une accélération/freinage progressifs
/// purement côté client (voir README de app/ pour la note de validation).
class ControlPacket {
  /// 0.0 = braqué à droite, 0.5 = centre, 1.0 = braqué à gauche.
  final double steering;

  /// 0.0 (relâché) à 1.0 (à fond).
  final double throttle;

  /// 0.0 (relâché) à 1.0 (à fond).
  final double brake;

  /// Compteur de séquence 0-127, ré-émis par le jeu dans la télémétrie
  /// pour mesurer la latence aller-retour.
  final int sequenceId;

  const ControlPacket({
    required this.steering,
    required this.throttle,
    required this.brake,
    required this.sequenceId,
  });

  Uint8List toBytes() {
    final data = ByteData(16);
    data.setFloat32(0, steering.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(4, throttle.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(8, brake.clamp(0.0, 1.0), Endian.big);
    data.setFloat32(12, sequenceId.toDouble(), Endian.big);
    return data.buffer.asUint8List();
  }
}
