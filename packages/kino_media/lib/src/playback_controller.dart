import 'package:flutter/foundation.dart';
import 'package:kino_core/kino_core.dart';

/// How hardware decoding is attempted.
enum HardwareDecodeMode {
  /// Try VA-API / NVDEC and fall back to software silently. The default,
  /// because it is right on every machine where it works and merely slower on
  /// the ones where it does not.
  auto,

  /// Never ask for hardware. The escape hatch for the driver combinations that
  /// are broken, which is why the preference exists at all (spec §1).
  software,
}

/// Everything the application is allowed to know about playback.
///
/// This is the boundary the spec draws around the engine (§0.2). Above it,
/// nothing imports `media_kit`, nothing sees an mpv property name, and nothing
/// assumes libmpv is what is running — `tools/check_layer_purity.sh` fails the
/// build if that stops being true. The point is not purity for its own sake: it
/// is that dropping to `dart:ffi` for a property `media_kit` does not expose, or
/// replacing the engine outright, stays a change to one package.
///
/// Positions are `Duration` at this boundary and frames above it. Both appear
/// here because seeking is a duration operation and stepping is a frame
/// operation, and pretending otherwise pushes the conversion into every caller.
abstract class PlaybackController implements Listenable {
  /// The current snapshot. Never null; an unloaded player reports
  /// [PlaybackState.idle].
  PlaybackState get state;

  /// Opens [source] — a `file:` or `http(s):` URI.
  ///
  /// Completes when the engine has accepted the media, which is before the
  /// first frame; watch [state] for [PlaybackStatus.playing].
  Future<void> open(Uri source, {bool play = true});

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();

  /// Unloads the media and returns to the empty state.
  Future<void> stop();

  Future<void> seek(Duration position);

  /// Seeks so that [frame] is the frame displayed.
  ///
  /// Exact, not to the nearest keyframe: this is what review mode is for, and
  /// "seeking a 2-hour file lands within one frame" is an acceptance criterion.
  Future<void> seekToFrame(int frame);

  /// Moves [delta] frames, forward or back, and pauses.
  ///
  /// Backwards stepping is genuinely harder than forwards and some engines do
  /// not offer it; libmpv does, so it is in the interface rather than being
  /// approximated by a seek.
  Future<void> stepFrames(int delta);

  /// 0.25×–4×, with pitch-corrected audio.
  Future<void> setSpeed(double speed);

  /// 0–[PlaybackState.maxVolume] percent.
  Future<void> setVolume(int volume);
  Future<void> setMuted(bool muted);

  /// Selects a track of [kind], or turns it off when [id] is null.
  ///
  /// Only subtitles can meaningfully be turned off; passing null for video or
  /// audio is a no-op rather than an error, so a generic track menu does not
  /// have to special-case its own rows.
  Future<void> selectTrack(TrackKind kind, String? id);

  /// Adds an external subtitle file and selects it.
  Future<void> addSubtitleFile(Uri uri);

  /// Positive shows subtitles later than the audio.
  Future<void> setSubtitleDelay(Duration delay);
  Future<void> setAudioDelay(Duration delay);

  /// Writes a still to [path]. [withSubtitles] chooses between mpv's rendered
  /// and unrendered screenshot modes.
  Future<void> screenshot(String path, {bool withSubtitles = true});

  Future<void> dispose();
}
