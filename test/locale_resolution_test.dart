import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/app.dart';
import 'package:kino/l10n/generated/app_localizations.dart';

void main() {
  final supported = AppLocalizations.supportedLocales;

  group('resolveLocale', () {
    test('falls back to English, not to whatever sorts first', () {
      // The regression this exists for: Flutter's default resolution returns
      // supportedLocales.first when nothing matches, the generated list is
      // alphabetical, and a machine with no LANG set therefore came up German.
      expect(resolveLocale(null, supported), const Locale('en'));
      expect(supported.first.languageCode, 'de', reason: 'still alphabetical');
    });

    test('falls back to English for a language Kino does not have', () {
      expect(resolveLocale(const Locale('ja'), supported), const Locale('en'));
    });

    test('honours each supported language', () {
      for (final language in <String>['de', 'en', 'fr', 'it']) {
        expect(
          resolveLocale(Locale(language), supported).languageCode,
          language,
        );
      }
    });

    test('matches on language alone, so de_CH gets German', () {
      // Switzerland is the home market; de_CH, fr_CH and it_CH must not fall
      // through to English.
      for (final locale in <Locale>[
        const Locale('de', 'CH'),
        const Locale('fr', 'CH'),
        const Locale('it', 'CH'),
        const Locale('de', 'AT'),
        const Locale('en', 'GB'),
      ]) {
        expect(
          resolveLocale(locale, supported).languageCode,
          locale.languageCode,
          reason: '$locale was not matched by language',
        );
      }
    });
  });
}
