import 'package:meta/meta.dart';

import 'media_info.dart';

enum PlaybackStatus {
  /// Nothing loaded — the empty state.
  idle,

  /// A file has been handed to the engine and has not produced a frame yet.
  opening,

  playing,
  paused,

  /// Reached the end of the file and stopped there. Distinct from [paused]
  /// because auto-advance and the resume threshold both depend on it.
  ended,

  failed,
}

/// One immutable snapshot of the player.
///
/// A value rather than a bag of separate notifiers: the transport bar, the
/// track bar, the status bar and MPRIS all have to agree with each other, and
/// they cannot disagree about a single object.
@immutable
class PlaybackState {
  const PlaybackState({
    this.status = PlaybackStatus.idle,
    this.media,
    this.position = Duration.zero,
    this.buffered = Duration.zero,
    this.speed = 1,
    this.volume = 100,
    this.muted = false,
    this.subtitleDelay = Duration.zero,
    this.audioDelay = Duration.zero,
    this.error,
  });

  static const PlaybackState idle = PlaybackState();

  /// The volume ceiling (spec §1: 0–150 %). Above unity mpv amplifies, which
  /// clips; it is offered because quiet dialogue in a field recording is the
  /// reason people reach for it.
  static const int maxVolume = 150;

  final PlaybackStatus status;
  final MediaInfo? media;

  final Duration position;

  /// How far the network buffer reaches. Equal to the duration for a local
  /// file, which is what makes the track bar's buffered range disappear.
  final Duration buffered;

  final double speed;
  final int volume;
  final bool muted;

  /// Positive means the subtitles are shown later than the audio.
  final Duration subtitleDelay;
  final Duration audioDelay;

  final Object? error;

  bool get isPlaying => status == PlaybackStatus.playing;
  bool get hasMedia => media != null;

  Duration get duration => media?.duration ?? Duration.zero;

  /// The frame on screen, or null when there is no video to count frames of.
  int? get frame => media?.video?.frameRate.frameAt(position);

  /// 0..1, and never NaN — the track bar divides by this.
  double get progress {
    final total = duration.inMicroseconds;
    if (total <= 0) return 0;
    final ratio = position.inMicroseconds / total;
    return ratio.clamp(0.0, 1.0);
  }

  PlaybackState copyWith({
    PlaybackStatus? status,
    MediaInfo? media,
    Duration? position,
    Duration? buffered,
    double? speed,
    int? volume,
    bool? muted,
    Duration? subtitleDelay,
    Duration? audioDelay,
    Object? error,
    bool clearMedia = false,
    bool clearError = false,
  }) => PlaybackState(
    status: status ?? this.status,
    media: clearMedia ? null : (media ?? this.media),
    position: position ?? this.position,
    buffered: buffered ?? this.buffered,
    speed: speed ?? this.speed,
    volume: volume ?? this.volume,
    muted: muted ?? this.muted,
    subtitleDelay: subtitleDelay ?? this.subtitleDelay,
    audioDelay: audioDelay ?? this.audioDelay,
    error: clearError ? null : (error ?? this.error),
  );

  @override
  bool operator ==(Object other) =>
      other is PlaybackState &&
      other.status == status &&
      other.media == media &&
      other.position == position &&
      other.buffered == buffered &&
      other.speed == speed &&
      other.volume == volume &&
      other.muted == muted &&
      other.subtitleDelay == subtitleDelay &&
      other.audioDelay == audioDelay &&
      other.error == error;

  @override
  int get hashCode => Object.hash(
    status,
    media,
    position,
    buffered,
    speed,
    volume,
    muted,
    subtitleDelay,
    audioDelay,
    error,
  );
}
