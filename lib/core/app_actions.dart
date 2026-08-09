import 'package:kino_core/kino_core.dart';
import 'package:kino_media/kino_media.dart';
import 'package:path/path.dart' as path;

import 'commands.dart';
import 'theme.dart';
import 'window_controls.dart';

/// Every user command, implemented once.
///
/// The keyboard, and later the menu, the overlay bar and the context menu, all
/// route through here, so they cannot drift apart — the failure where a menu
/// item and its shortcut do subtly different things starts with two
/// implementations.
///
/// Nothing here touches a widget, which is what lets the whole command surface
/// be tested against a fake controller instead of a pumped window.
class AppActions {
  AppActions({
    required this.playback,
    required this.theme,
    required this.window,
    XdgPaths? paths,
    DateTime Function()? now,
  }) : paths = paths ?? XdgPaths.fromPlatform(),
       _now = now ?? DateTime.now;

  final PlaybackController playback;
  final ThemeController theme;
  final WindowControls window;
  final XdgPaths paths;
  final DateTime Function() _now;

  static const double _minSpeed = 0.25;
  static const double _maxSpeed = 4;

  Future<void> run(KinoCommand command) async {
    switch (command) {
      case KinoCommand.playPause:
        await playback.playOrPause();
      case KinoCommand.stop:
        await playback.stop();

      case KinoCommand.seekBackSmall:
        await seekBy(-SeekSteps.small);
      case KinoCommand.seekForwardSmall:
        await seekBy(SeekSteps.small);
      case KinoCommand.seekBackMedium:
        await seekBy(-SeekSteps.medium);
      case KinoCommand.seekForwardMedium:
        await seekBy(SeekSteps.medium);
      case KinoCommand.seekBackLarge:
        await seekBy(-SeekSteps.large);
      case KinoCommand.seekForwardLarge:
        await seekBy(SeekSteps.large);

      case KinoCommand.frameBack:
        await playback.stepFrames(-1);
      case KinoCommand.frameForward:
        await playback.stepFrames(1);

      case KinoCommand.volumeDown:
        await adjustVolume(-kVolumeStep);
      case KinoCommand.volumeUp:
        await adjustVolume(kVolumeStep);
      case KinoCommand.toggleMute:
        await playback.setMuted(!playback.state.muted);

      case KinoCommand.speedDown:
        await _scaleSpeed(1 / 1.1);
      case KinoCommand.speedUp:
        await _scaleSpeed(1.1);
      case KinoCommand.speedReset:
        await playback.setSpeed(1);

      case KinoCommand.toggleFullscreen:
        await window.setFullScreen(!await window.isFullScreen());
      case KinoCommand.exitFullscreen:
        // Never quits, and is a no-op in a window. Both halves are muscle
        // memory and neither is negotiable (spec §0.6).
        if (await window.isFullScreen()) await window.setFullScreen(false);

      case KinoCommand.screenshot:
        await takeScreenshot(withSubtitles: true);
      case KinoCommand.screenshotWithoutSubtitles:
        await takeScreenshot(withSubtitles: false);

      case KinoCommand.subtitleDelayBack:
        await playback.setSubtitleDelay(
          playback.state.subtitleDelay - kDelayStep,
        );
      case KinoCommand.subtitleDelayForward:
        await playback.setSubtitleDelay(
          playback.state.subtitleDelay + kDelayStep,
        );
      case KinoCommand.audioDelayBack:
        await playback.setAudioDelay(playback.state.audioDelay - kDelayStep);
      case KinoCommand.audioDelayForward:
        await playback.setAudioDelay(playback.state.audioDelay + kDelayStep);

      case KinoCommand.toggleTheme:
        theme.mode = switch (theme.mode) {
          KinoThemeMode.system => KinoThemeMode.dark,
          KinoThemeMode.dark => KinoThemeMode.light,
          KinoThemeMode.light => KinoThemeMode.system,
        };

      case KinoCommand.quit:
        await window.close();
    }
  }

  /// Seeks [delta] from the current position, clamped to the file.
  ///
  /// Clamped rather than passed through: seeking past the end is how a player
  /// ends up reporting a position no frame exists at, and seeking before zero
  /// is undefined in most demuxers.
  Future<void> seekBy(Duration delta) async {
    final state = playback.state;
    if (!state.hasMedia) return;

    var target = state.position + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (target > state.duration) target = state.duration;
    await playback.seek(target);
  }

  Future<void> adjustVolume(int delta) => playback.setVolume(
    (playback.state.volume + delta).clamp(0, PlaybackState.maxVolume),
  );

  Future<void> _scaleSpeed(double factor) {
    // Rounded to a hundredth so repeated presses do not accumulate a speed of
    // 1.0000000000000002 and show it.
    final scaled = (playback.state.speed * factor * 100).round() / 100;
    return playback.setSpeed(scaled.clamp(_minSpeed, _maxSpeed));
  }

  /// Writes a still to the pictures directory (spec §1).
  ///
  /// The filename carries the timestamp because a screenshot that silently
  /// overwrites the last one is worse than no screenshot.
  Future<String?> takeScreenshot({bool withSubtitles = true}) async {
    if (!playback.state.hasMedia) return null;
    final target = path.posix.join(paths.picturesDir, screenshotName(_now()));
    await playback.screenshot(target, withSubtitles: withSubtitles);
    return target;
  }

  /// `kino-20260808-174233.png`. Sorts chronologically as text, which is the
  /// only ordering a file manager is guaranteed to offer.
  static String screenshotName(DateTime when) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'kino-${when.year}${two(when.month)}${two(when.day)}'
        '-${two(when.hour)}${two(when.minute)}${two(when.second)}.png';
  }
}
