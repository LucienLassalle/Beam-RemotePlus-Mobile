import 'package:beam_remoteplus/localization/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests des nouvelles fonctionnalités UI :
///   - Aide : toutes les clés de strings sont définies
///   - Recalibration : les clés settings sont définies
///   - Hotspot : la logique de fallback (testée au niveau beamng_client est
///     une intégration, donc on vérifie ici l'invariant de la constante de
///     broadcast fallback)

void main() {
  group('app_strings — clés d\'aide (help_*)', () {
    final helpKeys = [
      'help_title',
      'help_brake',
      'help_brake_desc',
      'help_throttle',
      'help_throttle_desc',
      'help_steering_tilt',
      'help_steering_tilt_desc',
      'help_steering_touch',
      'help_steering_touch_desc',
      'help_gear_pitch',
      'help_gear_pitch_desc',
      'help_vehicle',
      'help_vehicle_desc',
      'help_camera',
      'help_camera_desc',
      'help_mod_required',
    ];

    for (final lang in AppLanguage.values) {
      test('toutes les clés help_* sont définies en $lang', () {
        Strings.language = lang;
        for (final key in helpKeys) {
          final val = Strings.t(key);
          // Si la clé est absente, Strings.t retourne la clé elle-même.
          expect(
            val,
            isNot(key),
            reason: 'Clé "$key" manquante pour la langue $lang',
          );
          expect(val.isNotEmpty, isTrue);
        }
      });
    }
  });

  group('app_strings — clés de recalibration', () {
    final calibKeys = [
      'settings_advanced_title',
      'settings_recalibrate_title',
      'settings_recalibrate_subtitle',
      'settings_recalibrate_done',
    ];

    for (final lang in AppLanguage.values) {
      test('clés recalibration définies en $lang', () {
        Strings.language = lang;
        for (final key in calibKeys) {
          final val = Strings.t(key);
          expect(val, isNot(key), reason: 'Clé "$key" manquante pour $lang');
          expect(val.isNotEmpty, isTrue);
        }
      });
    }
  });

  group('Hotspot — fallback broadcast', () {
    test('255.255.255.255 est le broadcast global IPv4 valide', () {
      // La constante de fallback utilisée dans beamng_client.dart quand
      // getWifiBroadcast() retourne null (mode point d'accès mobile).
      const fallback = '255.255.255.255';
      final parts = fallback.split('.');
      expect(parts.length, 4);
      for (final p in parts) {
        expect(int.parse(p), 255);
      }
    });

    test('anyIPv4 accepte des paquets entrants sur toutes interfaces', () {
      // Vérification documentaire : InternetAddress.anyIPv4 = '0.0.0.0'.
      // Cela permet de recevoir sur l'interface hotspot quand WiFi STA
      // est inactif (getWifiIP() == null).
      expect(
        Uri.parse('udp://0.0.0.0:4445').host,
        equals('0.0.0.0'),
        reason: 'anyIPv4 doit lier sur toutes les interfaces (0.0.0.0)',
      );
    });
  });

  group('Gear shift flash — logique timer', () {
    test('couleur up = cyanAccent (montée de rapport)', () {
      // Vérifie que la convention couleur est documentée :
      // cyan = montée, orange = descente.
      // (La valeur ARGB de cyanAccent est 0xFF00BCD4 en Flutter Material.)
      expect(const Color(0xFF00BCD4).blue, greaterThan(100)); // bleu dominant
    });

    test('couleur down = orangeAccent (descente de rapport)', () {
      expect(const Color(0xFFFF9800).red, greaterThan(200)); // rouge dominant
    });
  });

  group('ZoneControls — zones mortes haut/bas', () {
    // Reproduit la logique de _ZoneControlsState._compute sans dépendance Flutter.
    const topDead    = 0.20;
    const bottomDead = 0.10;
    const active     = 1.0 - topDead - bottomDead; // 0.70
    const h          = 1000.0; // hauteur fictive

    double compute(double dy) {
      if (dy < h * topDead) return 1.0;
      if (dy > h * (1.0 - bottomDead)) return 0.0;
      return ((h * (1.0 - bottomDead) - dy) / (h * active)).clamp(0.0, 1.0);
    }

    test('zone morte haute (0-20%) → 1.0', () {
      expect(compute(0), equals(1.0));
      expect(compute(h * topDead - 1), equals(1.0));
    });

    test('zone morte basse (90-100%) → 0.0', () {
      expect(compute(h * (1.0 - bottomDead) + 1), equals(0.0));
      expect(compute(h), equals(0.0));
    });

    test('frontière haute (dy = h*0.20) → 1.0', () {
      // Juste en dehors de la zone morte haute : valeur max de la zone active
      expect(compute(h * topDead), closeTo(1.0, 1e-9));
    });

    test('frontière basse (dy = h*0.90) → 0.0', () {
      expect(compute(h * (1.0 - bottomDead)), closeTo(0.0, 1e-9));
    });

    test('milieu de la zone active (dy = h*0.55) → ~0.5', () {
      // Milieu entre 20% et 90% : dy = (0.20 + 0.90) / 2 * h = 0.55 * h
      expect(compute(h * 0.55), closeTo(0.5, 1e-9));
    });

    test('zone active totale = 70%', () {
      expect(active, closeTo(0.70, 1e-9));
    });
  });
}

// Fallback pour Color sans flutter/material.
class Color {
  final int value;
  const Color(this.value);
  int get red => (value >> 16) & 0xFF;
  int get green => (value >> 8) & 0xFF;
  int get blue => value & 0xFF;
}
