import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kino/core/theme.dart';
import 'package:kino/l10n/generated/app_localizations.dart';
import 'package:kino/ui/app_shell.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_media/kino_media.dart';
import 'package:kino_review/kino_review.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import 'support/fake_playback_controller.dart';

// The bindings themselves are asserted in key_bindings_test.dart and their
// effects in app_actions_test.dart. What is left, and what this file is for, is
// the wiring in between: whether a key pressed at the window actually reaches a
// command. That depends on focus, which fails silently — the application looks
// perfect and simply ignores the keyboard.

PlaybackState _loaded() => PlaybackState(
  status: PlaybackStatus.playing,
  position: const Duration(minutes: 1),
  media: MediaInfo(
    source: Uri.file('/srv/footage/clip.mkv'),
    duration: const Duration(minutes: 10),
    video: const VideoFormat(
      width: 1920,
      height: 1080,
      frameRate: FrameRate.pal,
    ),
  ),
);

Future<FakePlaybackController> _pumpShell(
  WidgetTester tester, {
  FakeWindowControls? window,
}) async {
  const slate = SlateThemeData.dark();
  final playback = FakePlaybackController(state: _loaded());

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(),
        ),
        ListenableProvider<PlaybackController>.value(value: playback),
      ],
      child: MaterialApp(
        theme: slate.toMaterialTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, view) => SlateTheme(data: slate, child: view!),
        home: AppShell(windowControls: window ?? FakeWindowControls()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return playback;
}

void main() {
  testWidgets('the window takes focus, so no click is needed first', (
    tester,
  ) async {
    final playback = await _pumpShell(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(playback.calls, contains('playOrPause()'));
  });

  testWidgets('arrows seek, and the modifiers change the step', (tester) async {
    final playback = await _pumpShell(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(playback.calls.last, 'seek(65000)');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(playback.calls.last, 'seek(64000)');
  });

  testWidgets('comma and period step frames', (tester) async {
    final playback = await _pumpShell(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.period);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.comma);
    await tester.pump();

    expect(
      playback.calls,
      containsAllInOrder(<String>['stepFrames(1)', 'stepFrames(-1)']),
    );
  });

  testWidgets('m mutes', (tester) async {
    final playback = await _pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(playback.calls.last, 'setMuted(true)');
  });

  testWidgets('f toggles fullscreen and Esc leaves it', (tester) async {
    final window = FakeWindowControls();
    await _pumpShell(tester, window: window);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(window.fullScreen, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(window.fullScreen, isFalse);
    expect(window.closed, 0, reason: 'Esc must never quit');
  });

  testWidgets('an unbound key does nothing', (tester) async {
    final playback = await _pumpShell(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    expect(playback.calls, isEmpty);
  });
}
