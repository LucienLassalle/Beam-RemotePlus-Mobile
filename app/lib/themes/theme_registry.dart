import 'civetta/civetta_theme.dart';
import 'control_theme.dart';
import 'default/default_theme.dart';
import 'f4/f4_theme.dart';

/// Themes shipped with the app, in the order shown in the settings.
///
/// Adding a theme = one folder lib/themes/NAME/ + one line here.
/// See THEMES.md.
const List<ControlTheme> availableThemes = [
  DefaultTheme(),
  CivettaTheme(),
  F4Theme(),
];

/// Theme by name, falling back to the first one (e.g. a theme removed in a
/// newer version but still saved in the settings).
ControlTheme themeByName(String name) =>
    availableThemes.firstWhere((t) => t.name == name, orElse: () => availableThemes.first);
