import 'package:kino_review/kino_review.dart';
import 'package:test/test.dart';

void main() {
  group('Timecode, non-drop', () {
    test('formats SMPTE at 25 fps', () {
      expect(const Timecode(0, FrameRate.pal).format(), '00:00:00:00');
      expect(const Timecode(24, FrameRate.pal).format(), '00:00:00:24');
      expect(const Timecode(25, FrameRate.pal).format(), '00:00:01:00');
      expect(const Timecode(1500, FrameRate.pal).format(), '00:01:00:00');
      expect(const Timecode(90000, FrameRate.pal).format(), '01:00:00:00');
    });

    test('formats decimal from the exact position', () {
      expect(
        const Timecode(1, FrameRate.pal).format(TimecodeStyle.decimal),
        '00:00:00.040',
      );
      expect(
        const Timecode(1, FrameRate.ntsc).format(TimecodeStyle.decimal),
        '00:00:00.033',
      );
    });

    test('formats a negative frame with a leading sign', () {
      expect(const Timecode(-1, FrameRate.pal).format(), '-00:00:00:01');
    });

    test('parses what it formats', () {
      for (final frame in <int>[0, 1, 24, 25, 1500, 90000, 215999]) {
        final source = Timecode(frame, FrameRate.pal).format();
        expect(
          Timecode.tryParse(source, FrameRate.pal)?.frame,
          frame,
          reason: source,
        );
      }
    });

    test('parses a decimal timecode', () {
      expect(Timecode.tryParse('00:00:01.000', FrameRate.pal)?.frame, 25);
      // A short fraction is read as tenths and hundredths, not as a raw count.
      expect(Timecode.tryParse('00:00:00.5', FrameRate.pal)?.frame, 12);
    });

    test('rejects what is not a timecode', () {
      expect(Timecode.tryParse('', FrameRate.pal), isNull);
      expect(Timecode.tryParse('12:34', FrameRate.pal), isNull);
      expect(Timecode.tryParse('00:60:00:00', FrameRate.pal), isNull);
      expect(Timecode.tryParse('00:00:61:00', FrameRate.pal), isNull);
      // 25 fps has frames 0..24; frame 25 does not exist.
      expect(Timecode.tryParse('00:00:00:25', FrameRate.pal), isNull);
    });

    test('adds and subtracts frames', () {
      const start = Timecode(1499, FrameRate.pal);
      expect((start + 1).format(), '00:01:00:00');
      expect((start - 1499).format(), '00:00:00:00');
    });
  });

  group('Timecode, drop-frame at 29.97', () {
    const rate = FrameRate.ntsc;

    Timecode at(int frame) => Timecode(frame, rate, dropFrame: true);

    test('uses a semicolon so the numbering is visible', () {
      expect(at(0).format(), '00:00:00;00');
    });

    test('skips two numbers at the top of most minutes', () {
      // The frame that would have been 00:00:59;29 + 1 is numbered ;02.
      expect(at(1799).format(), '00:00:59;29');
      expect(at(1800).format(), '00:01:00;02');
      expect(at(1801).format(), '00:01:00;03');
    });

    test('keeps the numbers at every tenth minute', () {
      expect(at(17982).format(), '00:10:00;00');
      expect(at(17983).format(), '00:10:00;01');
    });

    test('an hour of drop-frame numbering is an hour of frames', () {
      // 107892 frames is exactly one hour of 30000/1001 media, and that is what
      // drop-frame exists to make the timecode say.
      expect(at(107892).format(), '01:00:00;00');
    });

    test('parses its own output across the awkward boundaries', () {
      for (final frame in <int>[0, 1799, 1800, 17981, 17982, 107892, 215784]) {
        final source = at(frame).format();
        expect(
          Timecode.tryParse(source, rate)?.frame,
          frame,
          reason: '$source came back as a different frame',
        );
      }
    });

    test('a semicolon means drop-frame whatever the caller asked for', () {
      final parsed = Timecode.tryParse('00:01:00;02', rate);
      expect(parsed?.dropFrame, isTrue);
      expect(parsed?.frame, 1800);
    });

    test('non-drop numbering of the same frame reads differently', () {
      expect(const Timecode(1800, rate).format(), '00:01:00:00');
      expect(at(1800).format(), '00:01:00;02');
    });

    test('is refused at a rate where SMPTE does not define it', () {
      expect(Timecode.tryParse('00:01:00;02', FrameRate.pal), isNull);
      // The flag is inert rather than wrong when the rate cannot drop frames.
      expect(
        const Timecode(1500, FrameRate.pal, dropFrame: true).format(),
        '00:01:00:00',
      );
    });
  });

  group('Timecode, drop-frame at 59.94', () {
    const rate = FrameRate.ntscDouble;
    test('drops four numbers a minute', () {
      expect(Timecode(3600, rate, dropFrame: true).format(), '00:01:00;04');
      expect(Timecode(35964, rate, dropFrame: true).format(), '00:10:00;00');
    });
  });

  test('atPosition addresses the frame on screen', () {
    final timecode = Timecode.atPosition(
      const Duration(milliseconds: 79),
      FrameRate.pal,
    );
    expect(timecode.frame, 1);
    expect(timecode.format(), '00:00:00:01');
  });
}
