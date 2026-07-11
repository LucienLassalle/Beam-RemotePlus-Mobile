import 'package:flutter/material.dart';

import '../protocol/beamng_client.dart';
import '../protocol/mod_packets.dart';

/// Contrat qu'un thème communautaire doit implémenter pour apparaître dans
/// le sélecteur des paramètres. Un thème contrôle librement la disposition
/// de l'écran de pilotage : position des éléments, couleurs, typographie,
/// et quelles données il choisit d'afficher ou d'ignorer.
///
/// Volontairement HORS de portée d'un thème : les boutons Paramètres et
/// Aide. Ils sont posés par-dessus par [ControlScreen] (voir
/// `screens/control_screen.dart`), pour qu'aucun thème — buggé ou mal conçu
/// — ne puisse enfermer l'utilisateur sans accès aux réglages (notamment la
/// sortie du mode lecture seule).
abstract class ControlTheme {
  String get id;
  String get displayName;

  Widget build(BuildContext context, ControlSurface surface);
}

/// Tout ce qu'un thème peut utiliser pour construire son écran.
///
/// Deux niveaux de liberté :
/// - Widgets déjà câblés ([steeringWidget], [pedalsWidget]...) : à
///   positionner où l'on veut, sans avoir à réimplémenter la détection
///   tactile ou la fusion de capteurs (lissage, rejet de secousse...).
/// - Données brutes ([telemetry], [modActive]...) pour un thème qui préfère
///   dessiner ses propres jauges avec sa propre typographie.
///
/// Un thème n'est pas obligé de tout utiliser : ce qu'il ignore est
/// simplement absent de sa mise en page.
class ControlSurface {
  /// Flux de télémétrie du mod (vide/silencieux tant que [modActive] est
  /// false — un thème doit prévoir un état "pas de données" raisonnable).
  final Stream<ModTelemetryPacket> telemetry;

  final bool modActive;
  final BeamngConnectionState connectionState;
  final Duration? latency;
  final bool useKmh;

  /// true quand le mode "interface en lecture seule" est actif : les
  /// widgets fournis ci-dessous respectent déjà cette contrainte (le volant
  /// et les pédales n'envoient plus rien), un thème peut s'en servir juste
  /// pour adapter son affichage (griser, etc.), sans logique à dupliquer.
  final bool readOnly;

  /// Couleur de flash au changement de rapport, ou null hors flash. Un
  /// thème peut l'ignorer complètement.
  final Color? gearFlashColor;

  /// Volant déjà configuré (mode tactile ou inclinaison, sensibilité,
  /// lissage... selon les réglages utilisateur) : à positionner où l'on
  /// veut. En mode inclinaison le widget est invisible (0x0) : le
  /// positionnement n'a alors pas d'importance visuelle.
  final Widget steeringWidget;

  /// Zones tactiles frein/accélérateur, déjà câblées, plein écran par
  /// défaut — un thème qui veut des pédales ailleurs peut l'envelopper
  /// dans un [SizedBox]/[Positioned] plus petit.
  final Widget pedalsWidget;

  /// Même contrôle que [pedalsWidget] (détection tactile strictement
  /// identique), mais sans aucun rendu visuel (pas de bordure, dégradé ou
  /// label) : pour un thème qui veut que son tableau de bord occupe tout
  /// l'écran sans que les pédales n'interfèrent visuellement.
  final Widget pedalsWidgetInvisible;

  /// Boutons caméra précédente/suivante (mod requis ; vide si le mod n'est
  /// pas actif).
  final Widget cameraButtonsWidget;

  /// Boutons changement de véhicule précédent/suivant.
  final Widget vehicleSwitchWidget;

  /// Bouton de réinitialisation du véhicule (appui maintenu).
  final Widget resetVehicleWidget;

  const ControlSurface({
    required this.telemetry,
    required this.modActive,
    required this.connectionState,
    required this.latency,
    required this.useKmh,
    required this.readOnly,
    required this.gearFlashColor,
    required this.steeringWidget,
    required this.pedalsWidget,
    required this.pedalsWidgetInvisible,
    required this.cameraButtonsWidget,
    required this.vehicleSwitchWidget,
    required this.resetVehicleWidget,
  });
}
