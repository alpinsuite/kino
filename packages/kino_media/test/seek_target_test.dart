import 'package:flutter_test/flutter_test.dart';
import 'package:kino_media/kino_media.dart';
import 'package:kino_review/kino_review.dart';

void main() {
  group('seekTargetForFrame', () {
    test('lands inside the frame it names, at every rate that matters', () {
      for (final rate in <FrameRate>[
        FrameRate.film,
        FrameRate.ntscFilm,
        FrameRate.pal,
        FrameRate.ntsc,
        FrameRate.ntscDouble,
        FrameRate.fps120,
      ]) {
        for (final frame in <int>[0, 1, 1799, 1800, 107892, 215999]) {
          final target = MediaKitPlaybackController.seekTargetForFrame(
            frame,
            rate,
          );
          expect(
            rate.frameAt(target),
            frame,
            reason: '$rate seeking to frame $frame landed elsewhere',
          );
        }
      }
    });

    test('is strictly inside the frame, not on either boundary', () {
      const rate = FrameRate.ntsc;
      const frame = 5000;
      final target = MediaKitPlaybackController.seekTargetForFrame(frame, rate);

      expect(target, greaterThan(rate.positionOf(frame)));
      expect(target, lessThan(rate.positionOf(frame + 1)));
    });

    test('a two-hour seek is still exact', () {
      // 2 hours at 29.97 is where a floating-point implementation has drifted
      // by whole frames — the acceptance criterion is one frame over that span.
      const rate = FrameRate.ntsc;
      final frame = rate.frameCount(const Duration(hours: 2));
      expect(
        rate.frameAt(
          MediaKitPlaybackController.seekTargetForFrame(frame, rate),
        ),
        frame,
      );
    });

    test('handles frame zero without seeking before the start', () {
      for (final rate in <FrameRate>[FrameRate.pal, FrameRate.ntsc]) {
        final target = MediaKitPlaybackController.seekTargetForFrame(0, rate);
        expect(target, greaterThanOrEqualTo(Duration.zero));
        expect(rate.frameAt(target), 0);
      }
    });
  });
}
