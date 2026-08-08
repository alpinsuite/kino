import 'annotation.dart';
import 'review_document.dart';
import 'timecode.dart';

/// Text renderings of a review pass.
///
/// CSV and Markdown live here because they are string formatting over the
/// document and nothing else — a headless test can assert every character. PDF
/// export does not: it needs a page, fonts and a composited still, so it stays
/// in the application layer and reads these same fields.
abstract final class ReviewExport {
  /// RFC 4180. Excel and LibreOffice both open this without a dialog.
  static String toCsv(
    ReviewDocument document, {
    TimecodeStyle style = TimecodeStyle.smpte,
    bool dropFrame = false,
    String mediaTitle = '',
  }) {
    final rows = StringBuffer()..writeln('timecode,frame,category,author,note');

    for (final annotation in document.inFrameOrder) {
      final timecode = Timecode(
        annotation.frame,
        document.frameRate,
        dropFrame: dropFrame,
      );
      rows.writeln(
        <String>[
          timecode.format(style),
          '${annotation.frame}',
          document.categoryOf(annotation)?.label ?? '',
          annotation.author.name,
          annotation.note,
        ].map(_csvField).join(','),
      );
    }
    // The title is a comment-free format's only place for provenance, so it
    // goes in a trailing column-free line rather than corrupting the header.
    return mediaTitle.isEmpty
        ? rows.toString()
        : '# $mediaTitle\n${rows.toString()}';
  }

  /// What gets pasted into an email when the recipient will not open an
  /// attachment.
  static String toMarkdown(
    ReviewDocument document, {
    TimecodeStyle style = TimecodeStyle.smpte,
    bool dropFrame = false,
    String mediaTitle = '',
  }) {
    final out = StringBuffer();
    if (mediaTitle.isNotEmpty) out.writeln('# $mediaTitle\n');
    out
      ..writeln('| Timecode | Category | Author | Note |')
      ..writeln('| --- | --- | --- | --- |');

    for (final annotation in document.inFrameOrder) {
      final timecode = Timecode(
        annotation.frame,
        document.frameRate,
        dropFrame: dropFrame,
      );
      out.writeln(
        '| `${timecode.format(style)}` '
        '| ${_markdownCell(document.categoryOf(annotation)?.label ?? '')} '
        '| ${_markdownCell(annotation.author.name)} '
        '| ${_markdownCell(annotation.note)} |',
      );
    }
    return out.toString();
  }

  static String _csvField(String value) {
    if (!value.contains(RegExp('[",\r\n]'))) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  /// A newline inside a cell ends the table; a bare pipe starts a new column.
  static String _markdownCell(String value) => value
      .replaceAll('|', r'\|')
      .replaceAll('\r\n', '<br>')
      .replaceAll('\n', '<br>');
}

/// Convenience for the side panel: the categories actually used, in the order
/// they first appear on the timeline.
extension ReviewDocumentSummary on ReviewDocument {
  List<AnnotationCategory> get usedCategories {
    final seen = <String>{};
    final used = <AnnotationCategory>[];
    for (final annotation in inFrameOrder) {
      final category = categoryOf(annotation);
      if (category != null && seen.add(category.id)) used.add(category);
    }
    return List<AnnotationCategory>.unmodifiable(used);
  }
}
