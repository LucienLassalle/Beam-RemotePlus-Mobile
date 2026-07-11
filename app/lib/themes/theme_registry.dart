import 'civetta_theme.dart';
import 'control_theme.dart';
import 'default_theme.dart';
import 'f4_theme.dart';

/// Thèmes livrés avec l'app. Pour en ajouter un : créer un fichier
/// `<nom>_theme.dart` dans ce dossier implémentant [ControlTheme], puis
/// l'ajouter ici — une contribution communautaire type passe par une PR sur
/// ce fichier et le nouveau fichier de thème.
final List<ControlTheme> availableThemes = [
  DefaultTheme(),
  CivettaTheme(),
  F4Theme(),
];

ControlTheme themeById(String id) => availableThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => availableThemes.first,
    );
