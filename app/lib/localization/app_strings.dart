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
    'settings_advanced_title': {
      AppLanguage.fr: 'Options avancées',
      AppLanguage.en: 'Advanced',
    },
    'settings_recalibrate_title': {
      AppLanguage.fr: 'Recalibrer la direction',
      AppLanguage.en: 'Recalibrate steering',
    },
    'settings_recalibrate_subtitle': {
      AppLanguage.fr: 'Remet le centre à zéro depuis la position actuelle',
      AppLanguage.en: 'Re-zeroes the center from current holding position',
    },
    'settings_recalibrate_done': {
      AppLanguage.fr: 'Calibration lancée…',
      AppLanguage.en: 'Recalibrating…',
    },
    'help_title': {
      AppLanguage.fr: 'Aide — Contrôles',
      AppLanguage.en: 'Help — Controls',
    },
    'help_brake': {
      AppLanguage.fr: 'Frein',
      AppLanguage.en: 'Brake',
    },
    'help_brake_desc': {
      AppLanguage.fr: 'Zone gauche : glisser vers le haut',
      AppLanguage.en: 'Left zone: slide up',
    },
    'help_throttle': {
      AppLanguage.fr: 'Accélérateur',
      AppLanguage.en: 'Throttle',
    },
    'help_throttle_desc': {
      AppLanguage.fr: 'Zone droite : glisser vers le haut',
      AppLanguage.en: 'Right zone: slide up',
    },
    'help_steering_tilt': {
      AppLanguage.fr: 'Direction (inclinaison)',
      AppLanguage.en: 'Steering (tilt)',
    },
    'help_steering_tilt_desc': {
      AppLanguage.fr: 'Incliner le téléphone gauche / droite',
      AppLanguage.en: 'Tilt phone left / right',
    },
    'help_steering_touch': {
      AppLanguage.fr: 'Direction (tactile)',
      AppLanguage.en: 'Steering (touch)',
    },
    'help_steering_touch_desc': {
      AppLanguage.fr: 'Glisser le doigt horizontalement (centre)',
      AppLanguage.en: 'Drag finger horizontally (center)',
    },
    'help_gear_pitch': {
      AppLanguage.fr: 'Changement de rapport',
      AppLanguage.en: 'Gear shift',
    },
    'help_gear_pitch_desc': {
      AppLanguage.fr: 'Pitch avant = montée · Pitch arrière = descente (mod + boîte manuelle)',
      AppLanguage.en: 'Pitch forward = up · Pitch back = down (mod + manual gearbox)',
    },
    'help_vehicle': {
      AppLanguage.fr: 'Changer de véhicule',
      AppLanguage.en: 'Switch vehicle',
    },
    'help_vehicle_desc': {
      AppLanguage.fr: 'Boutons ◀ ▶ en haut à gauche (mod requis)',
      AppLanguage.en: '◀ ▶ buttons top-left (mod required)',
    },
    'help_camera': {
      AppLanguage.fr: 'Changer de caméra',
      AppLanguage.en: 'Switch camera',
    },
    'help_camera_desc': {
      AppLanguage.fr: 'Boutons caméra en bas au centre (mod requis)',
      AppLanguage.en: 'Camera buttons bottom-center (mod required)',
    },
    'help_mod_required': {
      AppLanguage.fr: 'Mod requis',
      AppLanguage.en: 'Mod required',
    },
    'reset_vehicle_tooltip': {
      AppLanguage.fr: 'Maintenir pour réinitialiser le véhicule',
      AppLanguage.en: 'Hold to reset vehicle',
    },
    'reset_vehicle_done': {
      AppLanguage.fr: 'Véhicule réinitialisé',
      AppLanguage.en: 'Vehicle reset',
    },
    'help_reset_vehicle': {
      AppLanguage.fr: 'Réinitialiser le véhicule',
      AppLanguage.en: 'Reset vehicle',
    },
    'help_reset_vehicle_desc': {
      AppLanguage.fr: 'Bouton ⟲ en haut au centre : maintenir pour confirmer (mod requis)',
      AppLanguage.en: '⟲ button top-center: hold to confirm (mod required)',
    },
    'debug_mode_tooltip': {
      AppLanguage.fr: 'Mode debug (logs de connexion détaillés)',
      AppLanguage.en: 'Debug mode (detailed connection logs)',
    },
    'debug_mode_on': {
      AppLanguage.fr: 'Mode debug activé : voir adb logcat',
      AppLanguage.en: 'Debug mode on: check adb logcat',
    },
    'debug_mode_off': {
      AppLanguage.fr: 'Mode debug désactivé',
      AppLanguage.en: 'Debug mode off',
    },
  };
}
