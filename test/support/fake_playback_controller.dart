import 'package:flutter/foundation.dart';
import 'package:kino/core/window_controls.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_media/kino_media.dart';

/// Records what the command layer asked the engine to do.
///
/// Lives in the test tree rather than in `kino_media`: it exists to make
/// assertions, not to be shipped, and a fake in `lib/` is a fake something will
/// eventually reach for in production.
class FakePlaybackController extends ChangeNotifier
    implements PlaybackController {
  FakePlaybackController({PlaybackState? state})
    : _state = state ?? PlaybackState.idle;

  PlaybackState _state;

  /// Every call, in order, as `'method(argument)'`.
  final List<String> calls = <String>[];

  @override
  PlaybackState get state => _state;

  set state(PlaybackState value) {
    _state = value;
    notifyListeners();
  }

  @override
  Future<void> open(Uri source, {bool play = true}) async {
    calls.add('open($source)');
  }

  @override
  Future<void> play() async => calls.add('play()');

  @override
  Future<void> pause() async => calls.add('pause()');

  @override
  Future<void> playOrPause() async => calls.add('playOrPause()');

  @override
  Future<void> stop() async => calls.add('stop()');

  @override
  Future<void> seek(Duration position) async {
    calls.add('seek(${position.inMilliseconds})');
    _state = _state.copyWith(position: position);
  }

  @override
  Future<void> seekToFrame(int frame) async => calls.add('seekToFrame($frame)');

  @override
  Future<void> stepFrames(int delta) async => calls.add('stepFrames($delta)');

  @override
  Future<void> setSpeed(double speed) async {
    calls.add('setSpeed($speed)');
    _state = _state.copyWith(speed: speed);
  }

  @override
  Future<void> setVolume(int volume) async {
    calls.add('setVolume($volume)');
    _state = _state.copyWith(volume: volume);
  }

  @override
  Future<void> setMuted(bool muted) async {
    calls.add('setMuted($muted)');
    _state = _state.copyWith(muted: muted);
  }

  @override
  Future<void> selectTrack(TrackKind kind, String? id) async {
    calls.add('selectTrack(${kind.name}, $id)');
  }

  @override
  Future<void> addSubtitleFile(Uri uri) async {
    calls.add('addSubtitleFile($uri)');
  }

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    calls.add('setSubtitleDelay(${delay.inMilliseconds})');
    _state = _state.copyWith(subtitleDelay: delay);
  }

  @override
  Future<void> setAudioDelay(Duration delay) async {
    calls.add('setAudioDelay(${delay.inMilliseconds})');
    _state = _state.copyWith(audioDelay: delay);
  }

  @override
  Future<void> screenshot(String path, {bool withSubtitles = true}) async {
    calls.add('screenshot($path, subtitles: $withSubtitles)');
  }

  @override
  Future<void> dispose() async => super.dispose();
}

/// Records fullscreen and close, and answers what it was last told.
class FakeWindowControls implements WindowControls {
  bool fullScreen = false;
  int closed = 0;

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async => fullScreen = value;

  @override
  Future<void> close() async => closed++;
}
