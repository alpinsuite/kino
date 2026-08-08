import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_review/kino_review.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'playback_controller.dart';

/// [PlaybackController] over libmpv, via `media_kit`.
///
/// This is the only file in the repository that names an mpv property. Where
/// `media_kit` models something, its model is used; where it does not — frame
/// stepping, exact seeking, the delays, `volume-max`, the hardware-decoder
/// readout — the escape hatch is [NativePlayer], which is the documented way in
/// and is a great deal less work than the `dart:ffi` fallback the spec keeps in
/// reserve.
class MediaKitPlaybackController extends ChangeNotifier
    implements PlaybackController {
  MediaKitPlaybackController({this.hardwareDecode = HardwareDecodeMode.auto}) {
    _player = Player(configuration: const PlayerConfiguration(title: 'Kino'));
    _video = VideoController(_player);
    _configure();
    _listen();
  }

  /// Loads libmpv and registers the texture bridge. Must run before the first
  /// controller is built, and before `runApp`.
  ///
  /// Returns the reason it failed, or null on success — it does **not** throw.
  /// libmpv is resolved at runtime and may simply be absent, and letting that
  /// escape `main` kills the process before `runApp` with no window and no
  /// message. The caller falls back to [UnavailablePlaybackController] so the
  /// interface can open and say what is wrong.
  static Object? ensureInitialized() {
    try {
      MediaKit.ensureInitialized();
      return null;
    } on Object catch (error) {
      return error;
    }
  }

  late final Player _player;
  late final VideoController _video;

  /// Fixed at construction: mpv's `hwdec` can be changed live, but a file
  /// already open keeps the decoder it was opened with, so a preference change
  /// rebuilds the controller rather than pretending to take effect.
  final HardwareDecodeMode hardwareDecode;

  final List<StreamSubscription<Object?>> _subscriptions =
      <StreamSubscription<Object?>>[];

  PlaybackState _state = PlaybackState.idle;
  Uri? _source;
  FrameRate? _frameRate;
  String? _hardwareDecoder;
  bool _disposed = false;

  @override
  PlaybackState get state => _state;

  /// The engine-side video handle the surface widget renders.
  ///
  /// Deliberately not on [PlaybackController]: it is a `media_kit` type, and
  /// letting it onto the interface would put one in every widget that touches
  /// playback. [PlaybackSurface] is the one consumer.
  VideoController get videoController => _video;

  NativePlayer get _native => _player.platform! as NativePlayer;

  Future<void> _configure() async {
    // mpv caps volume at 100 unless told otherwise, and §1 asks for 150.
    await _native.setProperty('volume-max', '${PlaybackState.maxVolume}');
    // Speed changes must not turn voices into chipmunks.
    await _native.setProperty('audio-pitch-correction', 'yes');
    await _native.setProperty(
      'hwdec',
      hardwareDecode == HardwareDecodeMode.software ? 'no' : 'auto-safe',
    );
    await _native.setProperty('deinterlace', 'auto');
    // Subtitles beside the video and one directory down, which is where every
    // download puts them.
    await _native.setProperty('sub-auto', 'fuzzy');
    await _native.setProperty('sub-file-paths', 'Subs:subs:Subtitles');
  }

  void _listen() {
    void on<T>(Stream<T> stream, void Function(T value) handler) {
      _subscriptions.add(stream.listen(handler));
    }

    on<Duration>(_player.stream.position, (position) {
      _emit(_state.copyWith(position: position));
    });
    on<Duration>(_player.stream.buffer, (buffer) {
      _emit(_state.copyWith(buffered: buffer));
    });
    on<bool>(_player.stream.playing, (playing) {
      if (_state.status == PlaybackStatus.idle) return;
      _emit(
        _state.copyWith(
          status: playing ? PlaybackStatus.playing : PlaybackStatus.paused,
        ),
      );
    });
    on<bool>(_player.stream.completed, (completed) {
      if (completed) _emit(_state.copyWith(status: PlaybackStatus.ended));
    });
    on<double>(_player.stream.volume, (volume) {
      _emit(_state.copyWith(volume: volume.round()));
    });
    on<double>(_player.stream.rate, (rate) {
      _emit(_state.copyWith(speed: rate));
    });
    on<String>(_player.stream.error, (message) {
      _emit(_state.copyWith(status: PlaybackStatus.failed, error: message));
    });
    // Duration, tracks and dimensions all land at slightly different moments
    // during an open, and any of them can change mid-file for a stream, so the
    // description is rebuilt rather than assembled once.
    on<Duration>(_player.stream.duration, (_) => unawaited(_refreshMedia()));
    on<Tracks>(_player.stream.tracks, (_) => unawaited(_refreshMedia()));
    on<Track>(_player.stream.track, (_) => unawaited(_refreshMedia()));
  }

  void _emit(PlaybackState next) {
    if (_disposed || next == _state) return;
    _state = next;
    notifyListeners();
  }

  Future<void> _refreshMedia() async {
    final source = _source;
    if (source == null || _disposed) return;

    _frameRate = await _readFrameRate();
    _hardwareDecoder = await _readHardwareDecoder();
    if (_disposed) return;

    final playerState = _player.state;
    final width = playerState.width;
    final height = playerState.height;
    final selected = playerState.track.video;

    _emit(
      _state.copyWith(
        media: MediaInfo(
          source: source,
          duration: playerState.duration,
          title: _titleOf(source),
          video: (width == null || height == null || width == 0)
              ? null
              : VideoFormat(
                  width: width,
                  height: height,
                  frameRate: _frameRate ?? FrameRate.fps30,
                  codec: selected.codec,
                  hardwareDecoder: _hardwareDecoder,
                ),
          tracks: <MediaTrack>[
            ..._map(playerState.tracks.video, TrackKind.video),
            ..._map(playerState.tracks.audio, TrackKind.audio),
            ..._map(playerState.tracks.subtitle, TrackKind.subtitle),
          ],
          chapters: await _readChapters(),
        ),
      ),
    );
  }

  static String _titleOf(Uri source) {
    if (source.pathSegments.isEmpty) return source.toString();
    final last = source.pathSegments.last;
    return last.isEmpty ? source.toString() : Uri.decodeComponent(last);
  }

  Iterable<MediaTrack> _map(List<Object?> tracks, TrackKind kind) sync* {
    for (final track in tracks) {
      // Every concrete track type is a `_Track`, which is private; the fields
      // below are the intersection, reached through the public subclasses.
      if (track is VideoTrack) {
        yield _one(
          track.id,
          kind,
          track.title,
          track.language,
          track.codec,
          track.isDefault,
        );
      } else if (track is AudioTrack) {
        yield _one(
          track.id,
          kind,
          track.title,
          track.language,
          track.codec,
          track.isDefault,
        );
      } else if (track is SubtitleTrack) {
        yield _one(
          track.id,
          kind,
          track.title,
          track.language,
          track.codec,
          track.isDefault,
          track.uri,
        );
      }
    }
  }

  static MediaTrack _one(
    String id,
    TrackKind kind,
    String? title,
    String? language,
    String? codec,
    bool? isDefault, [
    bool isExternal = false,
  ]) => MediaTrack(
    id: id,
    kind: kind,
    title: title,
    language: language,
    codec: codec,
    isDefault: isDefault ?? false,
    isExternal: isExternal,
  );

  Future<FrameRate?> _readFrameRate() async {
    // The container's declared rate, not the estimated one: an estimate wobbles
    // frame to frame, and every frame index in review mode is counted against
    // whatever this returns.
    final reported = await _property('container-fps');
    final parsed = double.tryParse(reported ?? '');
    if (parsed != null && parsed > 0) return FrameRate.fromDouble(parsed);

    final fromTrack = _player.state.track.video.fps;
    return fromTrack == null ? null : FrameRate.fromDouble(fromTrack);
  }

  Future<String?> _readHardwareDecoder() async {
    final current = await _property('hwdec-current');
    if (current == null || current.isEmpty || current == 'no') return null;
    return current;
  }

  Future<List<Chapter>> _readChapters() async {
    final count = int.tryParse(await _property('chapter-list/count') ?? '');
    if (count == null || count <= 0) return const <Chapter>[];

    final chapters = <Chapter>[];
    for (var index = 0; index < count; index++) {
      final seconds = double.tryParse(
        await _property('chapter-list/$index/time') ?? '',
      );
      chapters.add(
        Chapter(
          index: index,
          start: Duration(
            microseconds: ((seconds ?? 0) * Duration.microsecondsPerSecond)
                .round(),
          ),
          title: await _property('chapter-list/$index/title'),
        ),
      );
    }
    return chapters;
  }

  /// mpv throws for a property that does not apply to the current file, which
  /// is routine — a file with no chapters has no `chapter-list/count`.
  Future<String?> _property(String name) async {
    try {
      return await _native.getProperty(name);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> open(Uri source, {bool play = true}) async {
    _source = source;
    _frameRate = null;
    _emit(
      PlaybackState(
        status: PlaybackStatus.opening,
        volume: _state.volume,
        muted: _state.muted,
        speed: _state.speed,
      ),
    );
    await _player.open(Media(source.toString()), play: play);
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> stop() async {
    await _player.stop();
    _source = null;
    _frameRate = null;
    _emit(
      PlaybackState(
        volume: _state.volume,
        muted: _state.muted,
        speed: _state.speed,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    // `absolute+exact` rather than mpv's default keyframe seek. Keyframe
    // seeking is faster and lands up to several seconds away, which fails the
    // "within one frame of the requested position" criterion outright.
    final seconds = position.inMicroseconds / Duration.microsecondsPerSecond;
    await _native.command(<String>[
      'seek',
      seconds.toStringAsFixed(6),
      'absolute+exact',
    ]);
  }

  @override
  Future<void> seekToFrame(int frame) {
    final rate = _frameRate;
    if (rate == null) return Future<void>.value();
    return seek(seekTargetForFrame(frame, rate));
  }

  /// The position to seek to in order to land on [frame].
  ///
  /// The midpoint of the frame, not its first microsecond. Seeking to the exact
  /// boundary puts the request at the mercy of how the container rounded that
  /// timestamp, and a rounding of one microsecond the wrong way displays the
  /// frame *before* the one asked for — which is the single failure this whole
  /// path exists to avoid.
  ///
  /// Static and visible for testing because it is the only real arithmetic in
  /// this package, and it cannot be exercised through an engine in CI.
  @visibleForTesting
  static Duration seekTargetForFrame(int frame, FrameRate rate) {
    final start = rate.positionOf(frame);
    final next = rate.positionOf(frame + 1);
    return start + (next - start) ~/ 2;
  }

  @override
  Future<void> stepFrames(int delta) async {
    if (delta == 0) return;
    // mpv's own commands rather than a computed seek: they are exact, they are
    // cheap, and `frame-back-step` is the one an engine without it cannot fake.
    final command = delta > 0 ? 'frame-step' : 'frame-back-step';
    for (var step = 0; step < delta.abs(); step++) {
      await _native.command(<String>[command]);
    }
  }

  @override
  Future<void> setSpeed(double speed) =>
      _player.setRate(speed.clamp(0.25, 4.0));

  @override
  Future<void> setVolume(int volume) =>
      _player.setVolume(volume.clamp(0, PlaybackState.maxVolume).toDouble());

  @override
  Future<void> setMuted(bool muted) async {
    await _native.setProperty('mute', muted ? 'yes' : 'no');
    _emit(_state.copyWith(muted: muted));
  }

  @override
  Future<void> selectTrack(TrackKind kind, String? id) async {
    switch (kind) {
      case TrackKind.video:
        if (id != null) await _player.setVideoTrack(VideoTrack(id, null, null));
      case TrackKind.audio:
        if (id != null) await _player.setAudioTrack(AudioTrack(id, null, null));
      case TrackKind.subtitle:
        await _player.setSubtitleTrack(
          id == null ? SubtitleTrack.no() : SubtitleTrack(id, null, null),
        );
    }
  }

  @override
  Future<void> addSubtitleFile(Uri uri) =>
      _player.setSubtitleTrack(SubtitleTrack.uri(uri.toString()));

  @override
  Future<void> setSubtitleDelay(Duration delay) async {
    await _native.setProperty('sub-delay', _seconds(delay));
    _emit(_state.copyWith(subtitleDelay: delay));
  }

  @override
  Future<void> setAudioDelay(Duration delay) async {
    await _native.setProperty('audio-delay', _seconds(delay));
    _emit(_state.copyWith(audioDelay: delay));
  }

  static String _seconds(Duration delay) =>
      (delay.inMicroseconds / Duration.microsecondsPerSecond).toStringAsFixed(
        3,
      );

  @override
  Future<void> screenshot(String path, {bool withSubtitles = true}) =>
      // `subtitles` renders what is on screen; `video` takes the decoded frame
      // without the overlay, which is what a still for a report wants.
      _native.command(<String>[
        'screenshot-to-file',
        path,
        withSubtitles ? 'subtitles' : 'video',
      ]);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _player.dispose();
    super.dispose();
  }
}
