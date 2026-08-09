import 'package:flutter_test/flutter_test.dart';
import 'package:kino/core/app_actions.dart';
import 'package:kino/core/commands.dart';
import 'package:kino/core/theme.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_review/kino_review.dart';

import 'support/fake_playback_controller.dart';

PlaybackState _loaded({
  Duration position = const Duration(minutes: 1),
  Duration duration = const Duration(minutes: 10),
  int volume = 100,
  double speed = 1,
}) => PlaybackState(
  status: PlaybackStatus.playing,
  position: position,
  volume: volume,
  speed: speed,
  media: MediaInfo(
    source: Uri.file('/srv/footage/clip.mkv'),
    duration: duration,
    video: const VideoFormat(
      width: 1920,
      height: 1080,
      frameRate: FrameRate.pal,
    ),
  ),
);

({
  AppActions actions,
  FakePlaybackController playback,
  FakeWindowControls window,
  ThemeController theme,
})
_harness({PlaybackState? state}) {
  final playback = FakePlaybackController(state: state ?? _loaded());
  final window = FakeWindowControls();
  final theme = ThemeController();
  return (
    actions: AppActions(
      playback: playback,
      theme: theme,
      window: window,
      paths: const XdgPaths(
        environment: <String, String>{'HOME': '/home/alice'},
      ),
      now: () => DateTime(2026, 8, 8, 17, 42, 33),
    ),
    playback: playback,
    window: window,
    theme: theme,
  );
}

void main() {
  group('seeking', () {
    test('uses the three step sizes the specification names', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.seekForwardMedium);
      await h.actions.run(KinoCommand.seekBackSmall);
      await h.actions.run(KinoCommand.seekForwardLarge);

      expect(h.playback.calls, <String>[
        'seek(65000)', // +5 s from 1:00
        'seek(64000)', // -1 s
        'seek(124000)', // +60 s
      ]);
    });

    test('clamps at the start rather than seeking before zero', () async {
      final h = _harness(state: _loaded(position: const Duration(seconds: 2)));
      await h.actions.run(KinoCommand.seekBackLarge);
      expect(h.playback.calls, <String>['seek(0)']);
    });

    test('clamps at the end rather than past it', () async {
      final h = _harness(
        state: _loaded(
          position: const Duration(minutes: 9, seconds: 59),
          duration: const Duration(minutes: 10),
        ),
      );
      await h.actions.run(KinoCommand.seekForwardLarge);
      expect(h.playback.calls, <String>['seek(600000)']);
    });

    test('does nothing with no media loaded', () async {
      final h = _harness(state: PlaybackState.idle);
      await h.actions.run(KinoCommand.seekForwardMedium);
      expect(h.playback.calls, isEmpty);
    });
  });

  group('volume', () {
    test('steps and clamps to the 0..150 range', () async {
      final h = _harness(state: _loaded(volume: 148));
      await h.actions.run(KinoCommand.volumeUp);
      expect(h.playback.calls.last, 'setVolume(150)');

      final quiet = _harness(state: _loaded(volume: 2));
      await quiet.actions.run(KinoCommand.volumeDown);
      expect(quiet.playback.calls.last, 'setVolume(0)');
    });

    test('mute toggles from the current state', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.toggleMute);
      expect(h.playback.calls.last, 'setMuted(true)');
      await h.actions.run(KinoCommand.toggleMute);
      expect(h.playback.calls.last, 'setMuted(false)');
    });
  });

  group('speed', () {
    test('scales multiplicatively and stays within 0.25x..4x', () async {
      final h = _harness(state: _loaded(speed: 3.9));
      await h.actions.run(KinoCommand.speedUp);
      expect(h.playback.calls.last, 'setSpeed(4.0)');

      final slow = _harness(state: _loaded(speed: 0.26));
      await slow.actions.run(KinoCommand.speedDown);
      expect(slow.playback.calls.last, 'setSpeed(0.25)');
    });

    test('does not accumulate floating-point noise', () async {
      final h = _harness();
      for (var press = 0; press < 6; press++) {
        await h.actions.run(KinoCommand.speedUp);
      }
      for (final call in h.playback.calls) {
        // Anything like setSpeed(1.3310000000000004) fails this.
        expect(call.length, lessThanOrEqualTo('setSpeed(9.99)'.length));
      }
    });

    test('resets to exactly 1', () async {
      final h = _harness(state: _loaded(speed: 2.5));
      await h.actions.run(KinoCommand.speedReset);
      expect(h.playback.calls.last, 'setSpeed(1.0)');
    });
  });

  group('fullscreen', () {
    test('toggles', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.toggleFullscreen);
      expect(h.window.fullScreen, isTrue);
      await h.actions.run(KinoCommand.toggleFullscreen);
      expect(h.window.fullScreen, isFalse);
    });

    test('escape leaves fullscreen and never quits', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.toggleFullscreen);
      await h.actions.run(KinoCommand.exitFullscreen);
      expect(h.window.fullScreen, isFalse);
      expect(h.window.closed, 0);
    });

    test('escape in a window does nothing at all', () async {
      // The muscle-memory case: Esc must never be the key that loses a
      // two-hour position.
      final h = _harness();
      await h.actions.run(KinoCommand.exitFullscreen);
      expect(h.window.fullScreen, isFalse);
      expect(h.window.closed, 0);
    });
  });

  group('delays', () {
    test('subtitle delay steps by 100 ms in both directions', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.subtitleDelayForward);
      await h.actions.run(KinoCommand.subtitleDelayForward);
      await h.actions.run(KinoCommand.subtitleDelayBack);
      expect(h.playback.calls, <String>[
        'setSubtitleDelay(100)',
        'setSubtitleDelay(200)',
        'setSubtitleDelay(100)',
      ]);
    });

    test('audio delay is independent of subtitle delay', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.subtitleDelayForward);
      await h.actions.run(KinoCommand.audioDelayBack);
      expect(h.playback.calls, <String>[
        'setSubtitleDelay(100)',
        'setAudioDelay(-100)',
      ]);
    });
  });

  group('screenshots', () {
    test('go to the pictures directory with a timestamped name', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.screenshot);
      expect(h.playback.calls.single, contains('/home/alice/Pictures/'));
      expect(h.playback.calls.single, contains('kino-20260808-174233.png'));
      expect(h.playback.calls.single, contains('subtitles: true'));
    });

    test('can omit the subtitles', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.screenshotWithoutSubtitles);
      expect(h.playback.calls.single, contains('subtitles: false'));
    });

    test(
      'are refused with no media, rather than writing a blank file',
      () async {
        final h = _harness(state: PlaybackState.idle);
        expect(await h.actions.takeScreenshot(), isNull);
        expect(h.playback.calls, isEmpty);
      },
    );

    test('sort chronologically as plain text', () {
      final earlier = AppActions.screenshotName(DateTime(2026, 8, 8, 9, 5, 1));
      final later = AppActions.screenshotName(DateTime(2026, 8, 8, 17, 42, 33));
      expect(earlier.compareTo(later), lessThan(0));
      expect(earlier, 'kino-20260808-090501.png');
    });
  });

  group('frame stepping', () {
    test('steps one frame either way', () async {
      final h = _harness();
      await h.actions.run(KinoCommand.frameForward);
      await h.actions.run(KinoCommand.frameBack);
      expect(h.playback.calls, <String>['stepFrames(1)', 'stepFrames(-1)']);
    });
  });

  group('theme', () {
    test('cycles system, dark, light and back', () async {
      final h = _harness();
      expect(h.theme.mode, KinoThemeMode.system);
      await h.actions.run(KinoCommand.toggleTheme);
      expect(h.theme.mode, KinoThemeMode.dark);
      await h.actions.run(KinoCommand.toggleTheme);
      expect(h.theme.mode, KinoThemeMode.light);
      await h.actions.run(KinoCommand.toggleTheme);
      // System stays reachable, which a two-way toggle would lose.
      expect(h.theme.mode, KinoThemeMode.system);
    });
  });

  test('quit closes the window', () async {
    final h = _harness();
    await h.actions.run(KinoCommand.quit);
    expect(h.window.closed, 1);
  });

  test('every command is implemented', () async {
    // The switch in run() is exhaustive over the enum, so this asserts the
    // weaker but still useful thing: nothing throws.
    for (final command in KinoCommand.values) {
      final h = _harness();
      await h.actions.run(command);
    }
  });
}
