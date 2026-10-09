import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app ships in English and French: every string must exist in both.
void main() {
  Map<String, Object?> arb(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, Object?>;

  Set<String> keys(Map<String, Object?> file) => file.keys.where((k) => !k.startsWith('@')).toSet();

  test('English and French define exactly the same strings', () {
    final en = keys(arb('en')), fr = keys(arb('fr'));
    expect(en.difference(fr), isEmpty, reason: 'missing in French');
    expect(fr.difference(en), isEmpty, reason: 'missing in English');
  });

  test('no empty translation', () {
    for (final locale in ['en', 'fr']) {
      arb(locale).forEach((key, value) {
        if (!key.startsWith('@')) expect((value as String).trim(), isNotEmpty, reason: '$locale: $key');
      });
    }
  });

  test('placeholders match between languages', () {
    final en = arb('en'), fr = arb('fr');
    final placeholder = RegExp(r'\{(\w+)\}');
    for (final key in keys(en)) {
      final a = placeholder.allMatches(en[key]! as String).map((m) => m[1]).toSet();
      final b = placeholder.allMatches(fr[key]! as String).map((m) => m[1]).toSet();
      expect(b, a, reason: key);
    }
  });
}
