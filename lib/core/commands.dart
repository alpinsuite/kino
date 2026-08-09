import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Every action a key can invoke.
///
/// Concrete rather than parameterised — `seekForwardMedium`, not
/// `seek(Duration)` — because that is what a binding table is: a key maps to one
/// command, the way mpv's `input.conf` does. It also makes remapping a matter of
/// editing a map from activator to enum, with no expression to parse and
/// nothing user-supplied to validate beyond the key itself.
enum KinoCommand {
  playPause,
  stop,

  /// ±1 s, ±5 s and ±60 s (spec §1).
  seekBackSmall,
  seekForwardSmall,
  seekBackMedium,
  seekForwardMedium,
  seekBackLarge,
  seekForwardLarge,

  frameBack,
  frameForward,

  volumeDown,
  volumeUp,
  toggleMute,

  speedDown,
  speedUp,
  speedReset,

  toggleFullscreen,

  /// Never quits. `Esc` is muscle memory for "get me out of fullscreen", and a
  /// player that closes instead has thrown away the position as well.
  exitFullscreen,

  screenshot,
  screenshotWithoutSubtitles,

  subtitleDelayBack,
  subtitleDelayForward,
  audioDelayBack,
  audioDelayForward,

  toggleTheme,

  quit,
}

/// Seek steps, in the sizes §1 names.
abstract final class SeekSteps {
  static const Duration small = Duration(seconds: 1);
  static const Duration medium = Duration(seconds: 5);
  static const Duration large = Duration(minutes: 1);
}

/// How far one press shifts a subtitle or audio track (spec §1).
const Duration kDelayStep = Duration(milliseconds: 100);

/// The volume change one press makes, in percent.
const int kVolumeStep = 5;

/// The default bindings.
///
/// mpv's where a sensible equivalent exists, because mpv users are the first
/// audience and their fingers already know it: `Space` and `p` for play,
/// `.`/`,` for frame stepping, `m` mute, `f` fullscreen, `[`/`]` speed,
/// backspace to reset it, `s` screenshot, `9`/`0` volume.
///
/// Two deliberate departures:
///
/// * **Seeking follows §1, not mpv.** Arrows are ±5 s, Shift ±1 s, Ctrl ±60 s.
///   mpv puts ±60 s on plain Up/Down, which leaves the specification's own
///   scheme with nowhere to go; Up/Down carry volume here instead, which is
///   what every graphical player does.
/// * **`q` does not quit.** In mpv it does, and in a windowed application that
///   is a keystroke away from losing a two-hour position by accident. Quit is
///   `Ctrl+Q`, which is what every other window on the desktop uses.
const Map<ShortcutActivator, KinoCommand>
kDefaultKeyBindings = <ShortcutActivator, KinoCommand>{
  SingleActivator(LogicalKeyboardKey.space): KinoCommand.playPause,
  SingleActivator(LogicalKeyboardKey.keyP): KinoCommand.playPause,

  SingleActivator(LogicalKeyboardKey.arrowLeft): KinoCommand.seekBackMedium,
  SingleActivator(LogicalKeyboardKey.arrowRight): KinoCommand.seekForwardMedium,
  SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
      KinoCommand.seekBackSmall,
  SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
      KinoCommand.seekForwardSmall,
  SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
      KinoCommand.seekBackLarge,
  SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
      KinoCommand.seekForwardLarge,

  SingleActivator(LogicalKeyboardKey.period): KinoCommand.frameForward,
  SingleActivator(LogicalKeyboardKey.comma): KinoCommand.frameBack,

  SingleActivator(LogicalKeyboardKey.arrowUp): KinoCommand.volumeUp,
  SingleActivator(LogicalKeyboardKey.arrowDown): KinoCommand.volumeDown,
  SingleActivator(LogicalKeyboardKey.digit0): KinoCommand.volumeUp,
  SingleActivator(LogicalKeyboardKey.digit9): KinoCommand.volumeDown,
  SingleActivator(LogicalKeyboardKey.keyM): KinoCommand.toggleMute,

  SingleActivator(LogicalKeyboardKey.bracketRight): KinoCommand.speedUp,
  SingleActivator(LogicalKeyboardKey.bracketLeft): KinoCommand.speedDown,
  SingleActivator(LogicalKeyboardKey.backspace): KinoCommand.speedReset,

  SingleActivator(LogicalKeyboardKey.keyF): KinoCommand.toggleFullscreen,
  SingleActivator(LogicalKeyboardKey.f11): KinoCommand.toggleFullscreen,
  SingleActivator(LogicalKeyboardKey.escape): KinoCommand.exitFullscreen,

  SingleActivator(LogicalKeyboardKey.keyS): KinoCommand.screenshot,
  SingleActivator(LogicalKeyboardKey.keyS, shift: true):
      KinoCommand.screenshotWithoutSubtitles,

  // §1 puts the subtitle delay on Ctrl+Shift+arrows. Audio delay gets
  // "the same treatment", which is read here as the same shape one
  // modifier along.
  SingleActivator(LogicalKeyboardKey.arrowLeft, control: true, shift: true):
      KinoCommand.subtitleDelayBack,
  SingleActivator(LogicalKeyboardKey.arrowRight, control: true, shift: true):
      KinoCommand.subtitleDelayForward,
  SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
      KinoCommand.audioDelayBack,
  SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
      KinoCommand.audioDelayForward,

  SingleActivator(LogicalKeyboardKey.keyT, control: true):
      KinoCommand.toggleTheme,

  SingleActivator(LogicalKeyboardKey.keyQ, control: true): KinoCommand.quit,
};
