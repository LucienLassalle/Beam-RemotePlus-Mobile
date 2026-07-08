import 'dart:ui';

enum AppLanguage { fr, en }

/// Localisation minimale de l'app (français/anglais), sans dépendance au
/// package intl : simple table de correspondance clé -> traduction,
/// résolue une fois au démarrage depuis la langue de l'appareil.
class Strings {
  Strings._();

  static AppLanguage language = _detectLanguage();

  static AppLanguage _detectLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return code == 'fr' ? AppLanguage.fr : AppLanguage.en;
  }

  static String t(String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return entry[language] ?? entry[AppLanguage.en] ?? key;
  }

  static const Map<String, Map<AppLanguage, String>> _table = {
    'app_title': {
      AppLanguage.fr: 'BeamNG RemotePlus',
      AppLanguage.en: 'BeamNG RemotePlus',
    },
    'camera_permission_message': {
      AppLanguage.fr:
          'Autorisation caméra requise pour scanner le QR code affiché par BeamNG.drive.',
      AppLanguage.en:
          'Camera permission is required to scan the QR code shown by BeamNG.drive.',
    },
    'camera_permission_button': {
      AppLanguage.fr: 'Autoriser la caméra',
      AppLanguage.en: 'Allow camera',
    },
    'scan_hint': {
      AppLanguage.fr:
          'Dans BeamNG.drive : Options > Contrôles > Matériel > Application de contrôle à distance',
      AppLanguage.en:
          'In BeamNG.drive: Options > Controls > Hardware > Remote control app',
    },
    'invalid_qr': {
      AppLanguage.fr: 'QR code invalide.',
      AppLanguage.en: 'Invalid QR code.',
    },
    'settings_title': {
      AppLanguage.fr: 'Paramètres',
      AppLanguage.en: 'Settings',
    },
    'settings_tilt_title': {
      AppLanguage.fr: 'Direction par inclinaison',
      AppLanguage.en: 'Tilt steering',
    },
    'settings_tilt_subtitle': {
      AppLanguage.fr: 'Sinon : glisser le doigt horizontalement',
      AppLanguage.en: 'Otherwise: drag your finger horizontally',
    },
    'settings_sensitivity_title': {
      AppLanguage.fr: 'Sensibilité de la direction',
      AppLanguage.en: 'Steering sensitivity',
    },
    'settings_invert_title': {
      AppLanguage.fr: 'Inverser la direction',
      AppLanguage.en: 'Invert steering',
    },
    'settings_unit_title': {
      AppLanguage.fr: 'Unité km/h',
      AppLanguage.en: 'Use km/h',
    },
    'settings_unit_subtitle': {
      AppLanguage.fr: 'Désactiver pour mph',
      AppLanguage.en: 'Turn off for mph',
    },
    'settings_haptics_title': {
      AppLanguage.fr: 'Vibration au rupteur',
      AppLanguage.en: 'Shift point vibration',
    },
    'settings_haptics_subtitle': {
      AppLanguage.fr: 'Nécessite le mod (RPM non disponible sans lui)',
      AppLanguage.en: 'Requires the mod (RPM unavailable without it)',
    },
    'status_connected': {
      AppLanguage.fr: 'Connecté',
      AppLanguage.en: 'Connected',
    },
    'status_connecting': {
      AppLanguage.fr: 'Connexion...',
      AppLanguage.en: 'Connecting...',
    },
    'status_timeout': {AppLanguage.fr: 'Expiré', AppLanguage.en: 'Timed out'},
    'status_error': {AppLanguage.fr: 'Erreur', AppLanguage.en: 'Error'},
    'status_idle': {
      AppLanguage.fr: 'Déconnecté',
      AppLanguage.en: 'Disconnected',
    },
    'pedal_brake': {AppLanguage.fr: 'Frein', AppLanguage.en: 'Brake'},
    'pedal_throttle': {AppLanguage.fr: 'Accél.', AppLanguage.en: 'Gas'},
    'gauge_fuel': {AppLanguage.fr: 'Essence', AppLanguage.en: 'Fuel'},
    'gauge_temp': {AppLanguage.fr: 'Temp.', AppLanguage.en: 'Temp.'},
    'mod_banner': {
      AppLanguage.fr:
          'Installez le mod "Beam-RemotePlus" (par LucienLassalle) pour de meilleures performances, la vitesse, le régime moteur et un freinage/accélération progressifs.',
      AppLanguage.en:
          'Install the "Beam-RemotePlus" mod (by LucienLassalle) for better performance, live speed/RPM readouts and progressive throttle/braking.',
    },
    'connection_lost': {
      AppLanguage.fr: 'Connexion perdue.',
      AppLanguage.en: 'Connection lost.',
    },
    'vehicle_prev': {
      AppLanguage.fr: 'Véhicule précédent',
      AppLanguage.en: 'Previous vehicle',
    },
    'vehicle_next': {
      AppLanguage.fr: 'Véhicule suivant',
      AppLanguage.en: 'Next vehicle',
    },
    'cam_prev': {
      AppLanguage.fr: 'Caméra précédente',
      AppLanguage.en: 'Previous camera',
    },
    'cam_next': {
      AppLanguage.fr: 'Caméra suivante',
      AppLanguage.en: 'Next camera',
    },
    'settings_pitch_gear_title': {
      AppLanguage.fr: 'Changement de vitesse au pitch',
      AppLanguage.en: 'Pitch gear shifting',
    },
    'settings_pitch_gear_subtitle': {
      AppLanguage.fr: 'Avant = montée · Arrière = descente (boîte manuelle)',
      AppLanguage.en: 'Forward = up · Backward = down (manual gearbox)',
    },
  };
}
