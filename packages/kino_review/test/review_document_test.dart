import 'package:kino_review/kino_review.dart';
import 'package:test/test.dart';

Annotation _note(
  String id,
  int frame,
  String text, {
  String author = 'Inspector',
  String? categoryId,
  DateTime? updatedAt,
}) {
  final created = DateTime.utc(2026, 8, 7, 9);
  return Annotation(
    id: id,
    frame: frame,
    note: text,
    author: Actor(name: author),
    categoryId: categoryId,
    createdAt: created,
    updatedAt: updatedAt ?? created,
  );
}

ReviewDocument _document({
  List<Annotation> annotations = const <Annotation>[],
  List<AnnotationCategory> categories = const <AnnotationCategory>[],
  FrameRate rate = FrameRate.pal,
  MarkRange marks = MarkRange.empty,
}) => ReviewDocument(
  mediaKey: 'sha256:abc123',
  frameRate: rate,
  categories: categories,
  annotations: annotations,
  marks: marks,
);

void main() {
  group('ReviewDocument', () {
    test('lists annotations in playback order', () {
      final document = _document(
        annotations: <Annotation>[
          _note('c', 300, 'third'),
          _note('a', 100, 'first'),
          _note('b', 200, 'second'),
        ],
      );
      expect(document.inFrameOrder.map((a) => a.note), <String>[
        'first',
        'second',
        'third',
      ]);
    });

    test('adding an annotation with a known id replaces it', () {
      final document = _document(
        annotations: <Annotation>[_note('a', 100, 'old')],
      );
      final updated = document.withAnnotation(_note('a', 100, 'new'));
      expect(updated.annotations, hasLength(1));
      expect(updated.annotations.single.note, 'new');
    });

    test('removing an unknown id is a no-op', () {
      final document = _document(annotations: <Annotation>[_note('a', 1, 'x')]);
      expect(document.withoutAnnotation('nope').annotations, hasLength(1));
      expect(document.withoutAnnotation('a').annotations, isEmpty);
    });

    test('resolves a category, and tolerates a dangling id', () {
      const category = AnnotationCategory(
        id: 'defect',
        label: 'Defect',
        color: AnnotationColor.red,
      );
      final document = _document(
        categories: const <AnnotationCategory>[category],
        annotations: <Annotation>[
          _note('a', 10, 'weld', categoryId: 'defect'),
          _note('b', 20, 'orphan', categoryId: 'deleted-category'),
        ],
      );
      expect(document.categoryOf(document.inFrameOrder.first), category);
      expect(document.categoryOf(document.inFrameOrder.last), isNull);
    });

    test('round-trips through JSON', () {
      final document = _document(
        rate: FrameRate.ntsc,
        categories: const <AnnotationCategory>[
          AnnotationCategory(
            id: 'defect',
            label: 'Defect',
            color: AnnotationColor.red,
          ),
        ],
        annotations: <Annotation>[
          Annotation(
            id: 'a',
            frame: 7431,
            note: 'The weld is wrong',
            author: const Actor(name: 'R. Buache', userId: 'u-1'),
            categoryId: 'defect',
            shapes: const <DrawingShape>[
              DrawingShape(
                id: 's1',
                kind: ShapeKind.arrow,
                points: <ShapePoint>[
                  ShapePoint(0.2, 0.3),
                  ShapePoint(0.5, 0.6),
                ],
              ),
            ],
            createdAt: DateTime.utc(2026, 8, 7, 9),
            updatedAt: DateTime.utc(2026, 8, 7, 10),
          ),
        ],
        marks: const MarkRange(inFrame: 7000, outFrame: 8000),
      );

      final restored = ReviewDocument.decode(document.encode());
      expect(restored.mediaKey, document.mediaKey);
      expect(restored.frameRate, FrameRate.ntsc);
      expect(restored.categories, document.categories);
      expect(restored.annotations, document.annotations);
      expect(restored.marks, document.marks);
    });

    test('refuses a sidecar written by a newer build', () {
      expect(
        () => ReviewDocument.fromJson(<String, Object?>{
          'schemaVersion': ReviewDocument.schemaVersion + 1,
          'mediaKey': 'x',
          'frameRate': FrameRate.pal.toJson(),
        }),
        throwsFormatException,
      );
    });

    test('an unknown field does not stop a document loading', () {
      final json = _document(
        annotations: <Annotation>[_note('a', 5, 'hi')],
      ).toJson()..['somethingFromTheFuture'] = 42;
      expect(ReviewDocument.fromJson(json).annotations, hasLength(1));
    });
  });

  group('rebasedTo', () {
    test('moves frame indexes through the position, not through a ratio', () {
      final document = _document(
        rate: FrameRate.pal,
        // 25 fps frame 25 is exactly 1.000 s.
        annotations: <Annotation>[_note('a', 25, 'one second in')],
        marks: const MarkRange(inFrame: 25, outFrame: 50),
      );
      final rebased = document.rebasedTo(FrameRate.ntsc);
      expect(rebased.frameRate, FrameRate.ntsc);
      // 1.000 s at 30000/1001 is frame 29 (29.97 frames elapsed).
      expect(rebased.annotations.single.frame, 29);
      expect(rebased.marks.inFrame, 29);
      expect(rebased.marks.outFrame, 59);
    });

    test('is a no-op at the same rate', () {
      final document = _document(
        annotations: <Annotation>[_note('a', 25, 'x')],
      );
      expect(identical(document.rebasedTo(FrameRate.pal), document), isTrue);
    });
  });

  group('mergedWith', () {
    test('takes both reviewers\' notes', () {
      final mine = _document(annotations: <Annotation>[_note('a', 10, 'mine')]);
      final theirs = _document(
        annotations: <Annotation>[_note('b', 20, 'theirs', author: 'Second')],
      );
      final merged = mine.mergedWith(theirs);
      expect(merged.inFrameOrder.map((a) => a.note), <String>[
        'mine',
        'theirs',
      ]);
    });

    test('the later edit of a shared id wins', () {
      final older = _note(
        'a',
        10,
        'first pass',
        updatedAt: DateTime.utc(2026, 8, 7, 9),
      );
      final newer = _note(
        'a',
        11,
        'second pass',
        updatedAt: DateTime.utc(2026, 8, 7, 11),
      );

      expect(
        _document(annotations: <Annotation>[older])
            .mergedWith(_document(annotations: <Annotation>[newer]))
            .annotations
            .single
            .note,
        'second pass',
      );
      // ...and the other way round, so merge order does not decide the outcome.
      expect(
        _document(annotations: <Annotation>[newer])
            .mergedWith(_document(annotations: <Annotation>[older]))
            .annotations
            .single
            .note,
        'second pass',
      );
    });

    test('brings in categories the importer does not have', () {
      final mine = _document(
        categories: const <AnnotationCategory>[
          AnnotationCategory(id: 'defect', label: 'Defect'),
        ],
      );
      final theirs = _document(
        categories: const <AnnotationCategory>[
          AnnotationCategory(id: 'defect', label: 'Defekt'),
          AnnotationCategory(id: 'query', label: 'Query'),
        ],
      );
      final merged = mine.mergedWith(theirs);
      expect(merged.categories.map((c) => c.id), <String>['defect', 'query']);
      // A shared id keeps the importer's own label rather than being renamed
      // underneath them.
      expect(merged.categories.first.label, 'Defect');
    });

    test('converts an incoming pass counted at another rate', () {
      final mine = _document(rate: FrameRate.pal);
      final theirs = ReviewDocument(
        mediaKey: 'sha256:abc123',
        frameRate: FrameRate.ntsc,
        annotations: <Annotation>[_note('b', 30, 'about one second in')],
      );
      // 30 frames at 29.97 is 1.001 s, which is frame 25 at 25 fps.
      expect(mine.mergedWith(theirs).annotations.single.frame, 25);
    });

    test('leaves the importer\'s marks alone', () {
      final mine = _document(marks: const MarkRange(inFrame: 1, outFrame: 2));
      final theirs = _document(
        marks: const MarkRange(inFrame: 90, outFrame: 99),
      );
      expect(
        mine.mergedWith(theirs).marks,
        const MarkRange(inFrame: 1, outFrame: 2),
      );
    });
  });
}
