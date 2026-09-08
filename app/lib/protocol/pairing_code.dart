/// Code de sécurité d'appairage (5 chiffres, généré par
/// `core_remoteController` côté jeu).
///
/// Historiquement lu depuis le QR code affiché par BeamNG.drive
/// (Options > Contrôles > Matériel > Application de contrôle à distance).
/// Depuis la 0.39, ce QR encode une URL Play Store avec le code en
/// fragment : `https://play.google.com/store/apps/details?id=com.beamng.remotecontrol#54688`.
/// Avant, le format était `<texte>#<securityCode>` (vérifié depuis
/// QRCodeScanner.java). [tryParse] accepte les deux, plus une saisie
/// manuelle du code brut.
class PairingCode {
  final String securityCode;

  const PairingCode(this.securityCode);

  /// Tolérant volontairement : le contenu exact du QR a déjà changé une fois
  /// entre versions de BeamNG, et l'utilisateur peut aussi taper le code à
  /// la main. Stratégie :
  ///   1. si présence d'un `#`, on prend ce qui suit le dernier `#` ;
  ///   2. sinon on cherche la première suite de 4 à 6 chiffres ;
  ///   3. on valide que le résultat est bien numérique (4 à 6 chiffres).
  static PairingCode? tryParse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    String? candidate;
    final hashIndex = trimmed.lastIndexOf('#');
    if (hashIndex >= 0 && hashIndex < trimmed.length - 1) {
      candidate = trimmed.substring(hashIndex + 1).trim();
    }

    if (candidate == null || !_isValidCode(candidate)) {
      final match = RegExp(r'\d{4,6}').firstMatch(trimmed);
      candidate = match?.group(0);
    }

    if (candidate == null || !_isValidCode(candidate)) return null;
    return PairingCode(candidate);
  }

  static bool _isValidCode(String s) => RegExp(r'^\d{4,6}$').hasMatch(s);
}
