import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/l10n/generated/app_localizations.dart';
import 'package:kino/ui/empty_state.dart';
import 'package:slate_ui/slate_ui.dart';

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  const slate = SlateThemeData.dark();
  return MaterialApp(
    locale: locale,
    theme: slate.toMaterialTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, view) => SlateTheme(data: slate, child: view!),
    home: child,
  );
}

void main() {
  testWidgets('offers the open action and the drop hint', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_harness(EmptyState(onOpen: () => opened++)));

    expect(find.text('Open a file'), findsOneWidget);
    expect(find.text('or drop one onto the window'), findsOneWidget);
    expect(find.text('Nothing played yet'), findsOneWidget);

    await tester.tap(find.text('Open a file'));
    expect(opened, 1);
  });

  testWidgets('lists recent files by name, not by path', (tester) async {
    await tester.pumpWidget(
      _harness(
        EmptyState(
          onOpen: () {},
          recent: <Uri>[
            Uri.file('/srv/footage/north face.mkv'),
            Uri.parse('https://example.org/walkthrough.mp4'),
          ],
        ),
      ),
    );

    // The percent-encoding a file URL carries is not something to show a user.
    expect(find.text('north face.mkv'), findsOneWidget);
    expect(find.text('walkthrough.mp4'), findsOneWidget);
    expect(find.text('Nothing played yet'), findsNothing);
  });

  testWidgets('renders in all four locales without overflowing', (
    tester,
  ) async {
    // German is the long one and 600×380 is the window's declared minimum, so
    // this is the tightest layout the application is meant to survive.
    await tester.binding.setSurfaceSize(const Size(600, 380));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final locale in AppLocalizations.supportedLocales) {
      await tester.pumpWidget(
        _harness(
          EmptyState(
            onOpen: () {},
            recent: <Uri>[Uri.file('/srv/footage/inspection-2026-08-07.mkv')],
          ),
          locale: locale,
        ),
      );
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'the empty state overflowed in ${locale.languageCode}',
      );
    }
  });

  group('when the engine could not be loaded', () {
    testWidgets('explains instead of offering a file dialog', (tester) async {
      await tester.pumpWidget(
        _harness(
          EmptyState(
            onOpen: () {},
            recent: <Uri>[Uri.file('/srv/footage/clip.mkv')],
            engineFailure: 'Cannot find libmpv-2.dll in your system %PATH%.',
          ),
        ),
      );

      expect(find.text('Video playback is unavailable'), findsOneWidget);
      // Opening a file would achieve nothing, so the action is not offered.
      expect(find.text('Open a file'), findsNothing);
      expect(find.text('clip.mkv'), findsNothing);
    });

    testWidgets('shows the engine\'s own words, untranslated', (tester) async {
      // The searchable string is the whole value of the panel to someone
      // filing a bug; a translated paraphrase is not.
      const reason = 'Cannot find libmpv-2.dll in your system %PATH%.';
      await tester.pumpWidget(
        _harness(
          EmptyState(onOpen: () {}, engineFailure: reason),
          locale: const Locale('de'),
        ),
      );

      expect(find.text('Videowiedergabe nicht verfügbar'), findsOneWidget);
      expect(find.text(reason), findsOneWidget);
    });

    testWidgets('fits all four locales at the minimum window size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 380));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final locale in AppLocalizations.supportedLocales) {
        await tester.pumpWidget(
          _harness(
            EmptyState(
              onOpen: () {},
              engineFailure: 'Cannot find libmpv-2.dll in your system %PATH%.',
            ),
            locale: locale,
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: 'the failure panel overflowed in ${locale.languageCode}',
        );
      }
    });
  });

  test('all four locales are actually built', () {
    expect(
      AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
      <String>{'en', 'de', 'fr', 'it'},
    );
  });
}
