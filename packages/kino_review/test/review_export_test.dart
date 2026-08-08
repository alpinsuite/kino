import 'package:kino_review/kino_review.dart';
import 'package:test/test.dart';

Annotation _note(String id, int frame, String text, {String? categoryId}) =>
    Annotation(
      id: id,
      frame: frame,
      note: text,
      author: const Actor(name: 'R. Buache'),
      categoryId: categoryId,
      createdAt: DateTime.utc(2026, 8, 7),
      updatedAt: DateTime.utc(2026, 8, 7),
    );

ReviewDocument _document(List<Annotation> annotations) => ReviewDocument(
  mediaKey: 'sha256:abc',
  frameRate: FrameRate.pal,
  categories: const <AnnotationCategory>[
    AnnotationCategory(
      id: 'defect',
      label: 'Defect',
      color: AnnotationColor.red,
    ),
  ],
  annotations: annotations,
);

void main() {
  group('CSV', () {
    test('writes a header and one row per annotation, in playback order', () {
      final csv = ReviewExport.toCsv(
        _document(<Annotation>[
          _note('b', 1500, 'later'),
          _note('a', 25, 'earlier', categoryId: 'defect'),
        ]),
      );
      expect(csv.trim().split('\n'), <String>[
        'timecode,frame,category,author,note',
        '00:00:01:00,25,Defect,R. Buache,earlier',
        '00:01:00:00,1500,,R. Buache,later',
      ]);
    });

    test('quotes a field containing a comma, a quote or a newline', () {
      final csv = ReviewExport.toCsv(
        _document(<Annotation>[
          _note('a', 0, 'weld, porous; see "detail"\nsecond line'),
        ]),
      );
      expect(csv, contains('"weld, porous; see ""detail""\nsecond line"'));
    });

    test('carries the media title when one is given', () {
      final csv = ReviewExport.toCsv(
        _document(<Annotation>[_note('a', 0, 'x')]),
        mediaTitle: 'north-face-walkthrough.mkv',
      );
      expect(csv, startsWith('# north-face-walkthrough.mkv\n'));
    });

    test('renders decimal timecode when asked', () {
      final csv = ReviewExport.toCsv(
        _document(<Annotation>[_note('a', 25, 'x')]),
        style: TimecodeStyle.decimal,
      );
      expect(csv, contains('00:00:01.000,25,'));
    });
  });

  group('Markdown', () {
    test('emits a table', () {
      final markdown = ReviewExport.toMarkdown(
        _document(<Annotation>[_note('a', 25, 'weld', categoryId: 'defect')]),
      );
      expect(markdown, contains('| Timecode | Category | Author | Note |'));
      expect(
        markdown,
        contains('| `00:00:01:00` | Defect | R. Buache | weld |'),
      );
    });

    test('a pipe or a newline in a note does not break the table', () {
      final markdown = ReviewExport.toMarkdown(
        _document(<Annotation>[_note('a', 0, 'left|right\nnext')]),
      );
      final rows = markdown.trim().split('\n');
      expect(rows, hasLength(3));
      expect(rows.last, contains(r'left\|right<br>next'));
    });
  });

  test('usedCategories lists only what appears, in playback order', () {
    final document = ReviewDocument(
      mediaKey: 'k',
      frameRate: FrameRate.pal,
      categories: const <AnnotationCategory>[
        AnnotationCategory(id: 'query', label: 'Query'),
        AnnotationCategory(id: 'defect', label: 'Defect'),
        AnnotationCategory(id: 'unused', label: 'Unused'),
      ],
      annotations: <Annotation>[
        _note('a', 300, 'q', categoryId: 'query'),
        _note('b', 100, 'd', categoryId: 'defect'),
        _note('c', 200, 'd again', categoryId: 'defect'),
      ],
    );
    expect(document.usedCategories.map((c) => c.id), <String>[
      'defect',
      'query',
    ]);
  });
}
