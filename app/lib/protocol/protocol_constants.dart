/// Constantes du protocole UDP natif de BeamNG.drive
/// ("Options > Contrôles > Matériel > Application de contrôle à distance").
///
/// Vérifiées depuis le code source officiel archivé (BeamNG/remotecontrol,
/// Android/Udpsteering), pas de valeurs devinées.
class BeamngProtocol {
  /// Port sur lequel le jeu écoute le handshake de découverte ET les paquets
  /// de contrôle (steering/throttle/brake) envoyés par le téléphone.
  static const int hostPort = 4444;

  /// Port sur lequel le téléphone écoute la réponse de handshake puis le
  /// flux de télémétrie continu envoyé par le jeu.
  static const int clientPort = 4445;

  /// Préfixe du message de handshake envoyé par le téléphone.
  static const String handshakePrefix = 'beamng';

  /// Intervalle d'envoi des paquets de contrôle (ms). 50ms = 20Hz dans
  /// l'app d'origine ; on garde la même valeur par défaut, ajustable.
  static const int defaultControlIntervalMs = 50;

  /// Timeout d'une tentative de handshake avant nouvel essai.
  static const int discoveryRetryTimeoutMs = 250;

  /// Nombre max d'échecs I/O consécutifs avant d'abandonner la découverte.
  static const int discoveryMaxRetries = 20;
}

/// Constantes du protocole complémentaire ouvert par le mod optionnel
/// Beam-RemotePlus (télémétrie riche + pédales analogiques + commandes).
/// Absent du jeu natif ; l'app sonde ce canal et se dégrade proprement
/// s'il ne répond pas.
class ModProtocol {
  /// Port sur lequel le mod écoute (ping + contrôle + commandes), côté PC.
  static const int hostPort = 4446;

  /// Port sur lequel l'app écoute (pong + télémétrie), côté téléphone.
  static const int clientPort = 4447;

  static const String pingPrefix = 'beamngremoteplus|ping|';
  static const String pongPrefix = 'beamngremoteplus|pong|';

  /// Découverte sans code : l'app diffuse [discoverMessage] sur [hostPort],
  /// le mod répond `${helloPrefix}<code>|<label>` sur [clientPort].
  /// Remplace le scan du QR code natif de BeamNG, cassé depuis la 0.39.
  static const String discoverMessage = 'beamngremoteplus|discover';
  static const String helloPrefix = 'beamngremoteplus|hello|';

  /// Durée d'une passe de découverte automatique avant abandon.
  static const int discoverTimeoutMs = 4000;

  /// Intervalle entre deux diffusions de la sonde de découverte.
  static const int discoverRetryMs = 400;

  static const int pingTimeoutMs = 600;
  static const int controlIntervalMs = 16; // ~60Hz

  // Commandes textuelles (préfixe 'cmd|').
  // Discrimination du binaire par préfixe : le premier octet 'c' (0x63) ne
  // peut jamais apparaître en position 0 d'un paquet de contrôle binaire
  // (float32 steering ∈ [0,1] → LSB dans [0x00, 0x3F] en little-endian).
  static const String cmdPrefix = 'cmd|';
  static const String cmdNextVehicle = 'cmd|next_vehicle';
  static const String cmdPrevVehicle = 'cmd|prev_vehicle';
  static const String cmdCamNext = 'cmd|cam_next';
  static const String cmdCamPrev = 'cmd|cam_prev';
  static const String cmdGearUp = 'cmd|gear_up';
  static const String cmdGearDown = 'cmd|gear_down';
  static const String cmdRecoverStart = 'cmd|recover_start';
  static const String cmdRecoverStop = 'cmd|recover_stop';
}
