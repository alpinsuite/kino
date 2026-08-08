import 'package:flutter/foundation.dart';
import 'package:kino_core/kino_core.dart';

import 'playback_controller.dart';

/// The controller Kino runs on when the engine could not be loaded at all.
///
/// libmpv is resolved at runtime, so its absence is a state the application can
/// reach on a correctly built binary: the `.deb` declares the dependency, but
/// the portable tarball cannot, and a user who unpacks it on a machine without
/// libmpv installed would otherwise watch the process start and no window ever
/// appear — no error, no diagnostic, nothing to search for.
///
/// Every method is a no-op and [state] reports [PlaybackStatus.failed] with
/// [reason], so the interface can open, say what is wrong, and stay usable
/// rather than the process dying inside `main`.
class UnavailablePlaybackController extends ChangeNotifier
    implements PlaybackController {
  UnavailablePlaybackController(this.reason);

  /// What the engine said when it refused to load. Shown to the user, so it
  /// carries the underlying message rather than a generic apology.
  final Object reason;

  @override
  PlaybackState get state =>
      PlaybackState(status: PlaybackStatus.failed, error: reason);

  @override
  Future<void> open(Uri source, {bool play = true}) async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> playOrPause() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> seek(Duration position) async {}

  @override
  Future<void> seekToFrame(int frame) async {}

  @override
  Future<void> stepFrames(int delta) async {}

  @override
  Future<void> setSpeed(double speed) async {}

  @override
  Future<void> setVolume(int volume) async {}

  @override
  Future<void> setMuted(bool muted) async {}

  @override
  Future<void> selectTrack(TrackKind kind, String? id) async {}

  @override
  Future<void> addSubtitleFile(Uri uri) async {}

  @override
  Future<void> setSubtitleDelay(Duration delay) async {}

  @override
  Future<void> setAudioDelay(Duration delay) async {}

  @override
  Future<void> screenshot(String path, {bool withSubtitles = true}) async {}

  @override
  Future<void> dispose() async => super.dispose();
}
