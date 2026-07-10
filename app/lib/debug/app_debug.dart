/// Mode debug activable depuis l'écran de scan (icône bug dans l'AppBar).
/// Contrairement à des print() ajoutés/retirés au coup par coup à chaque
/// session de diagnostic, ce flag reste en permanence dans le code : on
/// l'active depuis l'app quand on a besoin d'investiguer (ex: échec de
/// connexion en mode hotspot), sans avoir à recompiler.
///
/// Non persisté sur disque (aucune autre option de réglage de l'app ne
/// l'est non plus) : repart à false à chaque lancement, ce qui est
/// approprié pour un outil de diagnostic ponctuel.
class AppDebug {
  AppDebug._();

  static bool enabled = false;

  static void log(String message) {
    if (!enabled) return;
    // ignore: avoid_print
    print('BeamRemotePlus DEBUG: $message');
  }
}
