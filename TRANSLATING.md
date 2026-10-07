# Translating the app

All texts of the app live in **one file per language**, no code to read:

```
app/lib/l10n/app_en.arb   <- English (reference)
app/lib/l10n/app_fr.arb   <- French
```

The app follows the phone language automatically (English when the
language is not translated); users can also pick a language in the settings.

## Fix or improve a translation

Edit the value in the `.arb` file of your language and open a pull request.
Keep the `{placeholders}` exactly as they are: they are replaced by values
(`"debugNoValue": "{field} returned nothing."`).

## Add a language

1. Copy `app_en.arb` to `app_<code>.arb` (`app_de.arb`, `app_es.arb`, `app_pt_BR.arb`...).
2. Change `"@@locale": "en"` to your code.
3. Translate every value. Lines starting with `@` are notes for translators,
   you can delete them in your file.
4. Add your language name in `_languageName` of
   `app/lib/features/settings/settings_sheet.dart`.
5. Check with `scripts/flutter.sh test`.

The in-game texts of the mod are translated the same way in the mod
repository (`src/locales/translations/<lang>/beamRemotePlus.translation.json`).
