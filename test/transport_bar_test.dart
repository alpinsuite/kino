import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/l10n/generated/app_localizations.dart';
import 'package:kino/ui/transport_bar.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_review/kino_review.dart';
import 'package:slate_ui/slate_ui.dart';

PlaybackState _loaded({
  PlaybackStatus status = PlaybackStatus.paused,
  bool muted = false,
}) => PlaybackState(
  status: status,
  muted: muted,
  media: MediaInfo(
    source: Uri.file('/srv/footage/clip.mkv'),
    duration: const Duration(minutes: 3),
    video: const VideoFormat(
      width: 1920,
      height: 1080,
      frameRate: FrameRate.pal,
    ),
  ),
);

Future<void> _pump(WidgetTester tester, PlaybackState state) async {
  const slate = SlateThemeData.dark();
  await tester.pumpWidget(
    MaterialApp(
      theme: slate.toMaterialTheme(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, view) => SlateTheme(data: slate, child: view!),
      home: Material(
        child: TransportBar(
          state: state,
          onPlayOrPause: () {},
          onSeek: (_) {},
          onVolume: (_) {},
          onToggleMute: () {},
        ),
      ),
    ),
  );
}

/// Finds the icon button drawing [glyph].
Finder _icon(SlateIconDraw glyph) => find.byWidgetPredicate(
  (widget) => widget is SlateIconButton && widget.icon == glyph,
);

void main() {
  group('play/pause', () {
    testWidgets('shows play when paused and pause when playing', (
      tester,
    ) async {
      await _pump(tester, _loaded());
      expect(_icon(SlateIcons.play), findsOneWidget);
      expect(_icon(SlateIcons.pause), findsNothing);

      await _pump(tester, _loaded(status: PlaybackStatus.playing));
      expect(_icon(SlateIcons.pause), findsOneWidget);
      expect(_icon(SlateIcons.play), findsNothing);
    });

    testWidgets('is one button, so it never moves under the pointer', (
      tester,
    ) async {
      await _pump(tester, _loaded());
      final paused = tester.getCenter(_icon(SlateIcons.play));

      await _pump(tester, _loaded(status: PlaybackStatus.playing));
      expect(tester.getCenter(_icon(SlateIcons.pause)), paused);
    });
  });

  group('mute', () {
    testWidgets('shows the speaker, struck through when muted', (tester) async {
      await _pump(tester, _loaded());
      expect(_icon(SlateIcons.volume), findsOneWidget);
      expect(_icon(SlateIcons.volumeOff), findsNothing);

      await _pump(tester, _loaded(muted: true));
      expect(_icon(SlateIcons.volumeOff), findsOneWidget);
      expect(_icon(SlateIcons.volume), findsNothing);
    });

    testWidgets('the tooltip says what pressing will do', (tester) async {
      // The glyph shows the state; the tooltip has to say the action, or the
      // pair is ambiguous to anyone reading only one of them.
      await _pump(tester, _loaded());
      expect(
        tester.widget<SlateIconButton>(_icon(SlateIcons.volume)).tooltip,
        'Mute',
      );

      await _pump(tester, _loaded(muted: true));
      expect(
        tester.widget<SlateIconButton>(_icon(SlateIcons.volumeOff)).tooltip,
        'Unmute',
      );
    });
  });

  testWidgets('every control is disabled with no media loaded', (tester) async {
    await _pump(tester, PlaybackState.idle);
    for (final button in tester.widgetList<SlateIconButton>(
      find.byType(SlateIconButton),
    )) {
      expect(button.onPressed, isNull);
    }
  });
}
