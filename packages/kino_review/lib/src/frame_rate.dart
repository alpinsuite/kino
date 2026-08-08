import 'package:meta/meta.dart';

/// A frame rate held as an exact rational, because the ones that matter are not
/// integers.
///
/// 29.97 is not a frame rate; 30000/1001 is. Storing it as a `double` means
/// every conversion between a position and a frame index carries a rounding
/// error, and over two hours that error is whole frames — which defeats the
/// point of a frame-accurate player.
@immutable
class FrameRate {
  const FrameRate(this.numerator, this.denominator)
    : assert(numerator > 0, 'numerator must be positive'),
      assert(denominator > 0, 'denominator must be positive');

  /// Builds the exact rational a reported decimal rate stands for.
  ///
  /// Containers report 23.976, 29.97 and 59.94 as decimals; those are rounded
  /// renderings of /1001 rates and are snapped back to them here. Anything else
  /// is taken at face value to a thousandth.
  factory FrameRate.fromDouble(double fps) {
    for (final candidate in <FrameRate>[
      film,
      ntscFilm,
      pal,
      ntsc,
      palDouble,
      ntscDouble,
      fps120,
    ]) {
      if ((candidate.asDouble - fps).abs() < 0.005) {
        return candidate;
      }
    }
    final numerator = (fps * 1000).round();
    return FrameRate(numerator, 1000).reduced;
  }

  final int numerator;
  final int denominator;

  static const FrameRate film = FrameRate(24, 1);
  static const FrameRate ntscFilm = FrameRate(24000, 1001); // 23.976
  static const FrameRate pal = FrameRate(25, 1);
  static const FrameRate ntsc = FrameRate(30000, 1001); // 29.97
  static const FrameRate fps30 = FrameRate(30, 1);
  static const FrameRate palDouble = FrameRate(50, 1);
  static const FrameRate ntscDouble = FrameRate(60000, 1001); // 59.94
  static const FrameRate fps60 = FrameRate(60, 1);
  static const FrameRate fps120 = FrameRate(120, 1);

  double get asDouble => numerator / denominator;

  /// The integer rate a timecode counts in: 30 for 29.97, 24 for 23.976.
  ///
  /// A timecode's frame field always counts whole frames, so it runs at the
  /// nominal rate even when the media does not.
  int get nominal => (numerator / denominator).ceil();

  /// Whether SMPTE drop-frame counting is defined for this rate.
  ///
  /// Only for the /1001 rates whose nominal is 30 or 60. Drop-frame is a
  /// renumbering trick that keeps a timecode's *hours* honest against a
  /// wall clock; it exists for broadcast delivery and nothing else. See
  /// docs/DECISIONS.md.
  bool get supportsDropFrame =>
      denominator == 1001 && (nominal == 30 || nominal == 60);

  /// The number of frame *numbers* skipped at the top of most minutes.
  int get droppedPerMinute => supportsDropFrame ? nominal ~/ 15 : 0;

  /// The index of the frame displayed at [position].
  ///
  /// Integer arithmetic throughout: at 60000/1001 a 24-hour position is about
  /// 5.2e15 in the intermediate product, comfortably inside a 64-bit int.
  int frameAt(Duration position) {
    final micros = position.inMicroseconds;
    final scaled = micros * numerator;
    final divisor = denominator * Duration.microsecondsPerSecond;
    // Truncating division rounds towards zero, which is wrong before the
    // origin: frame -1 covers the microsecond just before zero.
    if (scaled >= 0) return scaled ~/ divisor;
    return -((-scaled + divisor - 1) ~/ divisor);
  }

  /// The presentation time of frame [frame] — the start of the frame, which is
  /// the position to seek to in order to display it.
  ///
  /// Rounded *up* to the microsecond, never down. At 30000/1001 the true start
  /// of frame 1 is 33366.67 µs; truncating gives 33366, which is still frame 0,
  /// so `frameAt(positionOf(f))` would answer `f - 1` for most of the timeline
  /// and every seek would land a frame early. A microsecond of frame period is
  /// 33366 too many to give away and one too few to matter.
  Duration positionOf(int frame) {
    final scaled = frame * denominator * Duration.microsecondsPerSecond;
    // `~/` truncates towards zero, which already rounds a negative position
    // the way this needs.
    final micros = scaled >= 0
        ? (scaled + numerator - 1) ~/ numerator
        : scaled ~/ numerator;
    return Duration(microseconds: micros);
  }

  /// The number of frames in [duration], rounded to the nearest whole frame.
  ///
  /// A container's reported duration is rarely an exact multiple of the frame
  /// period, so truncating here would report a 100-frame clip as 99 frames.
  int frameCount(Duration duration) {
    final scaled = duration.inMicroseconds * numerator;
    final divisor = denominator * Duration.microsecondsPerSecond;
    return (scaled + divisor ~/ 2) ~/ divisor;
  }

  FrameRate get reduced {
    final divisor = _gcd(numerator, denominator);
    return FrameRate(numerator ~/ divisor, denominator ~/ divisor);
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  Map<String, Object?> toJson() => <String, Object?>{
    'numerator': numerator,
    'denominator': denominator,
  };

  static FrameRate fromJson(Map<String, Object?> json) => FrameRate(
    (json['numerator'] as num).toInt(),
    (json['denominator'] as num).toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is FrameRate &&
      other.numerator == numerator &&
      other.denominator == denominator;

  @override
  int get hashCode => Object.hash(numerator, denominator);

  @override
  String toString() => 'FrameRate($numerator/$denominator)';
}
