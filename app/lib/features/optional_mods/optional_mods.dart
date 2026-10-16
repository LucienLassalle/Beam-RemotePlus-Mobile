import '../../l10n/generated/app_localizations.dart';

/// Optional mods this app works with (none of them is needed). Their ids
/// are the ones of the mod's session message (see the mod's optionalMods.lua).
enum OptionalMod {
  tyreThermals('tyreThermals'),
  f4('f4'),
  cf26('cf26'),
  fr17('fr17');

  final String id;
  const OptionalMod(this.id);

  String name(AppLocalizations l10n) => switch (this) {
        OptionalMod.tyreThermals => l10n.optionalModTyreThermals,
        OptionalMod.f4 => l10n.optionalModF4,
        OptionalMod.cf26 => l10n.optionalModCf26,
        OptionalMod.fr17 => l10n.optionalModFr17,
      };

  /// What the mod adds on the phone.
  String features(AppLocalizations l10n) => switch (this) {
        OptionalMod.tyreThermals => l10n.optionalModTyreThermalsFeatures,
        OptionalMod.f4 => l10n.optionalModF4Features,
        OptionalMod.cf26 => l10n.optionalModCf26Features,
        OptionalMod.fr17 => l10n.optionalModFr17Features,
      };
}

/// State of an optional mod in the game, as the mod reports it.
enum OptionalModState {
  enabled,

  /// Installed but turned off in the game's mod manager.
  disabled,
  missing;

  /// `enabled`, `disabled`, `missing`; null for anything else.
  static OptionalModState? tryParse(String? name) {
    for (final state in values) {
      if (state.name == name) return state;
    }
    return null;
  }
}
