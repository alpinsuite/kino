import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'annotation.dart';
import 'frame_rate.dart';
import 'mark_range.dart';

/// One reviewer's pass over one file — what a `<video>.kino.json` sidecar holds.
///
/// The video is never touched. The sidecar sits beside it, or in the data
/// directory when the source is read-only.
@immutable
class ReviewDocument {
  const ReviewDocument({
    required this.mediaKey,
    required this.frameRate,
    this.categories = const <AnnotationCategory>[],
    this.annotations = const <Annotation>[],
    this.marks = MarkRange.empty,
  });

  /// Bumped only when an older reader would misread a newer file. Readers
  /// ignore fields they do not know, so adding one is not a version change.
  static const int schemaVersion = 1;

  /// Identifies the media by content, not by path — the same key the resume
  /// store uses, so a renamed file keeps its annotations.
  final String mediaKey;

  /// The rate the frame indexes in this document are counted against.
  ///
  /// Stored because it is the only thing that makes those indexes meaningful:
  /// a document read back against a different rate would put every note in the
  /// wrong place, and [rebasedTo] is the deliberate way to change it.
  final FrameRate frameRate;

  final List<AnnotationCategory> categories;
  final List<Annotation> annotations;
  final MarkRange marks;

  /// Annotations in playback order. Ties keep insertion order, so two notes on
  /// one frame read the way they were written.
  List<Annotation> get inFrameOrder {
    final sorted = annotations.toList()
      ..sort((a, b) => a.frame.compareTo(b.frame));
    return List<Annotation>.unmodifiable(sorted);
  }

  AnnotationCategory? categoryOf(Annotation annotation) => categories
      .firstWhereOrNull((category) => category.id == annotation.categoryId);

  ReviewDocument copyWith({
    FrameRate? frameRate,
    List<AnnotationCategory>? categories,
    List<Annotation>? annotations,
    MarkRange? marks,
  }) => ReviewDocument(
    mediaKey: mediaKey,
    frameRate: frameRate ?? this.frameRate,
    categories: categories ?? this.categories,
    annotations: annotations ?? this.annotations,
    marks: marks ?? this.marks,
  );

  ReviewDocument withAnnotation(Annotation annotation) {
    final next = annotations.toList();
    final existing = next.indexWhere((other) => other.id == annotation.id);
    if (existing >= 0) {
      next[existing] = annotation;
    } else {
      next.add(annotation);
    }
    return copyWith(annotations: next);
  }

  ReviewDocument withoutAnnotation(String id) => copyWith(
    annotations: annotations.where((other) => other.id != id).toList(),
  );

  /// Re-counts every frame index against [rate].
  ///
  /// Needed when a document was written against a container's misreported rate
  /// and the real one turns up later. Conversion goes through the position, not
  /// through a ratio of the indexes, so a note stays on the frame the reviewer
  /// was actually looking at.
  ReviewDocument rebasedTo(FrameRate rate) {
    if (rate == frameRate) return this;
    int convert(int frame) => rate.frameAt(frameRate.positionOf(frame));
    return ReviewDocument(
      mediaKey: mediaKey,
      frameRate: rate,
      categories: categories,
      annotations: annotations
          .map(
            (annotation) => Annotation(
              id: annotation.id,
              frame: convert(annotation.frame),
              note: annotation.note,
              author: annotation.author,
              categoryId: annotation.categoryId,
              shapes: annotation.shapes,
              createdAt: annotation.createdAt,
              updatedAt: annotation.updatedAt,
            ),
          )
          .toList(growable: false),
      marks: MarkRange(
        inFrame: marks.inFrame == null ? null : convert(marks.inFrame!),
        outFrame: marks.outFrame == null ? null : convert(marks.outFrame!),
      ),
    );
  }

  /// Folds a colleague's pass into this one (spec §7, import).
  ///
  /// Union by id; where both sides know an id, the later [Annotation.updatedAt]
  /// wins. Nothing is ever dropped for being unrecognised — an import that
  /// silently loses a note is worse than a conflict, because nobody finds out.
  /// [other]'s marks are ignored: they belong to whoever set them.
  ReviewDocument mergedWith(ReviewDocument other) {
    final rebased = other.frameRate == frameRate
        ? other
        : other.rebasedTo(frameRate);

    final byId = <String, Annotation>{
      for (final annotation in annotations) annotation.id: annotation,
    };
    for (final incoming in rebased.annotations) {
      final mine = byId[incoming.id];
      if (mine == null || incoming.updatedAt.isAfter(mine.updatedAt)) {
        byId[incoming.id] = incoming;
      }
    }

    final categoryIds = categories.map((category) => category.id).toSet();
    final mergedCategories = <AnnotationCategory>[
      ...categories,
      ...rebased.categories.where(
        (category) => !categoryIds.contains(category.id),
      ),
    ];

    return copyWith(
      categories: mergedCategories,
      annotations: byId.values.toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'mediaKey': mediaKey,
    'frameRate': frameRate.toJson(),
    'categories': categories.map((category) => category.toJson()).toList(),
    'annotations': inFrameOrder
        .map((annotation) => annotation.toJson())
        .toList(),
    if (!marks.isEmpty) 'marks': marks.toJson(),
  };

  static ReviewDocument fromJson(Map<String, Object?> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? schemaVersion;
    if (version > schemaVersion) {
      throw FormatException(
        'sidecar schema version $version is newer than this build understands '
        '($schemaVersion)',
      );
    }
    return ReviewDocument(
      mediaKey: json['mediaKey'] as String? ?? '',
      frameRate: FrameRate.fromJson(
        json['frameRate'] as Map<String, Object?>? ?? const {},
      ),
      categories: (json['categories'] as List<Object?>? ?? const <Object?>[])
          .map(
            (category) =>
                AnnotationCategory.fromJson(category as Map<String, Object?>),
          )
          .toList(growable: false),
      annotations: (json['annotations'] as List<Object?>? ?? const <Object?>[])
          .map(
            (annotation) =>
                Annotation.fromJson(annotation as Map<String, Object?>),
          )
          .toList(growable: false),
      marks: MarkRange.fromJson(
        json['marks'] as Map<String, Object?>? ?? const {},
      ),
    );
  }

  /// Pretty-printed on purpose: a sidecar sits in the user's own directory next
  /// to their footage, and they should be able to read and diff it.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  static ReviewDocument decode(String source) =>
      fromJson(jsonDecode(source) as Map<String, Object?>);
}
