import 'package:collection/collection.dart';
import 'package:kino_review/kino_review.dart';
import 'package:meta/meta.dart';

enum TrackKind { video, audio, subtitle }

/// One selectable stream.
///
/// The id is whatever the engine calls it and is passed straight back when
/// selecting; nothing above this layer should parse it.
@immutable
class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.kind,
    this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isExternal = false,
  });

  final String id;
  final TrackKind kind;
  final String? title;

  /// ISO 639 as the container reports it. Not normalised: `ger` and `deu` are
  /// both real and the interface should show what the file says.
  final String? language;

  final String? codec;
  final bool isDefault;

  /// True for a subtitle file loaded from beside the video rather than from
  /// inside it.
  final bool isExternal;

  @override
  bool operator ==(Object other) =>
      other is MediaTrack &&
      other.id == id &&
      other.kind == kind &&
      other.title == title &&
      other.language == language &&
      other.codec == codec &&
      other.isDefault == isDefault &&
      other.isExternal == isExternal;

  @override
  int get hashCode =>
      Object.hash(id, kind, title, language, codec, isDefault, isExternal);
}

@immutable
class Chapter {
  const Chapter({required this.index, required this.start, this.title});

  final int index;
  final Duration start;
  final String? title;

  @override
  bool operator ==(Object other) =>
      other is Chapter &&
      other.index == index &&
      other.start == start &&
      other.title == title;

  @override
  int get hashCode => Object.hash(index, start, title);
}

/// What the video stream actually is, once the engine has opened it.
@immutable
class VideoFormat {
  const VideoFormat({
    required this.width,
    required this.height,
    required this.frameRate,
    this.codec,
    this.hardwareDecoder,
  });

  final int width;
  final int height;

  /// Exact, not a decimal — everything in review mode counts against this.
  final FrameRate frameRate;

  final String? codec;

  /// The hardware decoder in use (`vaapi`, `nvdec`), or null for software.
  ///
  /// Surfaced rather than merely logged because "hardware decode is on by
  /// default with a visible indicator of which is in use" is an acceptance
  /// criterion, and because a silent fall back to software is the difference
  /// between a quiet laptop and a hot one.
  final String? hardwareDecoder;

  bool get isHardwareDecoded => hardwareDecoder != null;

  @override
  bool operator ==(Object other) =>
      other is VideoFormat &&
      other.width == width &&
      other.height == height &&
      other.frameRate == frameRate &&
      other.codec == codec &&
      other.hardwareDecoder == hardwareDecoder;

  @override
  int get hashCode =>
      Object.hash(width, height, frameRate, codec, hardwareDecoder);
}

/// Everything known about the open media.
@immutable
class MediaInfo {
  const MediaInfo({
    required this.source,
    required this.duration,
    this.title,
    this.video,
    this.tracks = const <MediaTrack>[],
    this.chapters = const <Chapter>[],
  });

  /// A `file:` or `http(s):` URI. Held as a URI rather than a path because
  /// both are first-class here.
  final Uri source;

  final Duration duration;
  final String? title;

  /// Null for an audio-only file, which Kino will still play.
  final VideoFormat? video;

  final List<MediaTrack> tracks;
  final List<Chapter> chapters;

  Iterable<MediaTrack> tracksOf(TrackKind kind) =>
      tracks.where((track) => track.kind == kind);

  /// Total frames, or null when there is no video stream to count.
  int? get frameCount => video?.frameRate.frameCount(duration);

  /// The chapter containing [position], or null when the file has none.
  Chapter? chapterAt(Duration position) =>
      chapters.lastWhereOrNull((chapter) => chapter.start <= position);

  @override
  bool operator ==(Object other) =>
      other is MediaInfo &&
      other.source == source &&
      other.duration == duration &&
      other.title == title &&
      other.video == video &&
      const ListEquality<MediaTrack>().equals(other.tracks, tracks) &&
      const ListEquality<Chapter>().equals(other.chapters, chapters);

  @override
  int get hashCode => Object.hash(
    source,
    duration,
    title,
    video,
    const ListEquality<MediaTrack>().hash(tracks),
    const ListEquality<Chapter>().hash(chapters),
  );
}
