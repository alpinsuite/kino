import 'package:kino_review/kino_review.dart';
import 'package:test/test.dart';

void main() {
  group('MarkRange', () {
    test('half a range is a legal state', () {
      const half = MarkRange(inFrame: 100);
      expect(half.isEmpty, isFalse);
      expect(half.isComplete, isFalse);
      expect(half.lengthInFrames, isNull);
      expect(half.contains(100), isFalse);
    });

    test('the out point is inside the range', () {
      const range = MarkRange(inFrame: 100, outFrame: 109);
      expect(range.lengthInFrames, 10);
      expect(range.contains(100), isTrue);
      expect(range.contains(109), isTrue);
      expect(range.contains(110), isFalse);
      expect(range.contains(99), isFalse);
    });

    test('a single-frame range is one frame long', () {
      const range = MarkRange(inFrame: 42, outFrame: 42);
      expect(range.lengthInFrames, 1);
      expect(range.contains(42), isTrue);
    });

    test('marks set out of order still describe the same range', () {
      const backwards = MarkRange(inFrame: 109, outFrame: 100);
      expect(backwards.start, 100);
      expect(backwards.end, 109);
      expect(backwards.lengthInFrames, 10);
      expect(backwards.loopTarget, 100);
    });

    test('reports its duration at a rate', () {
      const range = MarkRange(inFrame: 0, outFrame: 24);
      expect(range.durationAt(FrameRate.pal), const Duration(seconds: 1));
      expect(MarkRange.empty.durationAt(FrameRate.pal), isNull);
    });

    test('survives JSON, including the half-set case', () {
      const half = MarkRange(inFrame: 7);
      expect(MarkRange.fromJson(half.toJson()), half);
      expect(MarkRange.fromJson(MarkRange.empty.toJson()), MarkRange.empty);
    });
  });
}
