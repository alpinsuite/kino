import 'package:kino_review/kino_review.dart';
import 'package:test/test.dart';

void main() {
  group('FrameRate', () {
    test('snaps a reported decimal back to its exact rational', () {
      expect(FrameRate.fromDouble(29.97), FrameRate.ntsc);
      expect(FrameRate.fromDouble(23.976), FrameRate.ntscFilm);
      expect(FrameRate.fromDouble(59.94), FrameRate.ntscDouble);
      expect(FrameRate.fromDouble(25), FrameRate.pal);
    });

    test('takes an unrecognised rate at face value', () {
      expect(FrameRate.fromDouble(15), const FrameRate(15, 1));
      expect(FrameRate.fromDouble(12.5), const FrameRate(25, 2));
    });

    test('counts timecode frames at the nominal rate', () {
      expect(FrameRate.ntsc.nominal, 30);
      expect(FrameRate.ntscFilm.nominal, 24);
      expect(FrameRate.ntscDouble.nominal, 60);
      expect(FrameRate.pal.nominal, 25);
    });

    test('offers drop-frame only where SMPTE defines it', () {
      expect(FrameRate.ntsc.supportsDropFrame, isTrue);
      expect(FrameRate.ntscDouble.supportsDropFrame, isTrue);
      expect(FrameRate.ntscFilm.supportsDropFrame, isFalse);
      expect(FrameRate.fps30.supportsDropFrame, isFalse);
      expect(FrameRate.pal.supportsDropFrame, isFalse);
    });

    test('drops two numbers a minute at 29.97 and four at 59.94', () {
      expect(FrameRate.ntsc.droppedPerMinute, 2);
      expect(FrameRate.ntscDouble.droppedPerMinute, 4);
      expect(FrameRate.pal.droppedPerMinute, 0);
    });

    test('round-trips every frame of an hour at 29.97 without drifting', () {
      // Exhaustive rather than sampled: a rounding error here is a fraction of
      // a frame that only becomes a whole frame somewhere in the middle of a
      // long file, which is exactly where sampling would miss it.
      const rate = FrameRate.ntsc;
      for (var frame = 0; frame <= 107892; frame++) {
        final round = rate.frameAt(rate.positionOf(frame));
        if (round != frame) {
          fail('frame $frame came back as $round');
        }
      }
    });

    test('round-trips across the other rates that matter', () {
      for (final rate in <FrameRate>[
        FrameRate.film,
        FrameRate.ntscFilm,
        FrameRate.pal,
        FrameRate.ntscDouble,
        FrameRate.fps120,
      ]) {
        for (final frame in <int>[0, 1, 999, 100000, 1000001]) {
          expect(
            rate.frameAt(rate.positionOf(frame)),
            frame,
            reason: '$rate lost frame $frame',
          );
        }
      }
    });

    test('a frame boundary is the first microsecond of the new frame', () {
      const rate = FrameRate.ntsc;
      final start = rate.positionOf(100);
      expect(rate.frameAt(start), 100);
      expect(rate.frameAt(start - const Duration(microseconds: 1)), 99);
    });

    test('a position inside a frame resolves to that frame', () {
      const rate = FrameRate.pal; // 40 ms per frame
      expect(rate.frameAt(const Duration(milliseconds: 0)), 0);
      expect(rate.frameAt(const Duration(milliseconds: 39)), 0);
      expect(rate.frameAt(const Duration(milliseconds: 40)), 1);
      expect(rate.frameAt(const Duration(milliseconds: 79)), 1);
    });

    test('a position before the origin resolves to a negative frame', () {
      const rate = FrameRate.pal;
      expect(rate.frameAt(const Duration(milliseconds: -1)), -1);
      expect(rate.frameAt(const Duration(milliseconds: -40)), -1);
      expect(rate.frameAt(const Duration(milliseconds: -41)), -2);
    });

    test('rounds a duration to the nearest whole frame', () {
      const rate = FrameRate.pal;
      // A container reporting 4.0 s must not yield 99 frames.
      expect(rate.frameCount(const Duration(seconds: 4)), 100);
      expect(rate.frameCount(const Duration(milliseconds: 3999)), 100);
      expect(rate.frameCount(const Duration(milliseconds: 3980)), 100);
      expect(rate.frameCount(const Duration(milliseconds: 3979)), 99);
    });

    test('survives JSON', () {
      expect(FrameRate.fromJson(FrameRate.ntsc.toJson()), FrameRate.ntsc);
    });
  });
}
