import 'package:meta/meta.dart';

import 'frame_rate.dart';

/// How a frame index is rendered for a human.
enum TimecodeStyle {
  /// `HH:MM:SS:FF` — the frame field counts frames. What a review pass uses,
  /// because it names a frame rather than an instant.
  smpte,

  /// `HH:MM:SS.mmm` — milliseconds. What a transport bar shows.
  decimal,
}

/// A position on the timeline, addressed by frame.
///
/// The frame index is the value; everything else is a rendering of it. Never
/// store one of these as a string and parse it back to do arithmetic — add
/// frames.
@immutable
class Timecode {
  const Timecode(this.frame, this.rate, {this.dropFrame = false});

  /// The frame displayed at [position].
  factory Timecode.atPosition(
    Duration position,
    FrameRate rate, {
    bool dropFrame = false,
  }) => Timecode(rate.frameAt(position), rate, dropFrame: dropFrame);

  /// Reads `HH:MM:SS:FF`, `HH:MM:SS;FF` or `HH:MM:SS.mmm`.
  ///
  /// A `;` before the frame field is the SMPTE convention for drop-frame and is
  /// honoured whatever [dropFrame] says, because that is what the string means.
  /// Returns null rather than throwing: this backs a text field, where a
  /// half-typed value is the normal case and not an error.
  static Timecode? tryParse(
    String text,
    FrameRate rate, {
    bool dropFrame = false,
  }) {
    final match = _pattern.firstMatch(text.trim());
    if (match == null) return null;

    final hours = int.parse(match.group(1)!);
    final minutes = int.parse(match.group(2)!);
    final seconds = int.parse(match.group(3)!);
    if (minutes > 59 || seconds > 59) return null;

    final separator = match.group(4);
    final tail = match.group(5)!;

    if (separator == '.') {
      final millis = int.parse(tail.padRight(3, '0').substring(0, 3));
      final position = Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: millis,
      );
      return Timecode(rate.frameAt(position), rate, dropFrame: dropFrame);
    }

    final frames = int.parse(tail);
    if (frames >= rate.nominal) return null;
    final isDrop = separator == ';' || dropFrame;
    if (isDrop && !rate.supportsDropFrame) return null;
    return Timecode(
      _framesFromFields(hours, minutes, seconds, frames, rate, isDrop),
      rate,
      dropFrame: isDrop,
    );
  }

  // Hours are not anchored to two digits: an eight-hour rush exists.
  static final RegExp _pattern = RegExp(
    r'^(\d{1,3}):([0-5]?\d):([0-5]?\d)([:;.])(\d{1,3})$',
  );

  final int frame;
  final FrameRate rate;

  /// Whether the frame field is numbered with SMPTE drop-frame counting.
  ///
  /// Only meaningful when [FrameRate.supportsDropFrame]; ignored otherwise, so
  /// that a preference set globally does not have to be defended at every call.
  final bool dropFrame;

  bool get _isDrop => dropFrame && rate.supportsDropFrame;

  Duration get position => rate.positionOf(frame);

  Timecode operator +(int frames) =>
      Timecode(frame + frames, rate, dropFrame: dropFrame);

  Timecode operator -(int frames) =>
      Timecode(frame - frames, rate, dropFrame: dropFrame);

  /// Renders in [style]. Never locale-dependent — a timecode is not a number
  /// the reader formats, it is an address (spec §0.6).
  String format([TimecodeStyle style = TimecodeStyle.smpte]) =>
      style == TimecodeStyle.smpte ? _formatSmpte() : _formatDecimal();

  String _formatSmpte() {
    final negative = frame < 0;
    var counted = negative ? -frame : frame;
    final nominal = rate.nominal;

    if (_isDrop) counted = _toDropFrameNumbering(counted, rate);

    final frames = counted % nominal;
    var whole = counted ~/ nominal;
    final seconds = whole % 60;
    whole ~/= 60;
    final minutes = whole % 60;
    final hours = whole ~/ 60;

    final separator = _isDrop ? ';' : ':';
    return '${negative ? '-' : ''}${_two(hours)}:${_two(minutes)}'
        ':${_two(seconds)}$separator${_two(frames)}';
  }

  String _formatDecimal() => formatDuration(position);

  /// `HH:MM:SS.mmm` for a position that is not about a frame.
  ///
  /// A transport bar addresses an instant, not a frame, and asking it to supply
  /// a frame rate it does not need in order to print one is how a rate that is
  /// merely plausible ends up in the interface. Never locale-formatted.
  static String formatDuration(Duration position) {
    final micros = position.inMicroseconds;
    final negative = micros < 0;
    final total = negative ? -micros : micros;
    final millis = (total ~/ 1000) % 1000;
    final seconds = (total ~/ Duration.microsecondsPerSecond) % 60;
    final minutes = (total ~/ Duration.microsecondsPerMinute) % 60;
    final hours = total ~/ Duration.microsecondsPerHour;
    return '${negative ? '-' : ''}${_two(hours)}:${_two(minutes)}'
        ':${_two(seconds)}.${millis.toString().padLeft(3, '0')}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// Converts a real frame count to the frame *numbering* drop-frame uses.
  ///
  /// Drop-frame skips two numbers (four at 59.94) at the top of every minute
  /// except every tenth, so that the timecode's hour matches an hour of wall
  /// clock. No frames are discarded — only their labels.
  static int _toDropFrameNumbering(int frames, FrameRate rate) {
    final dropped = rate.droppedPerMinute;
    final nominal = rate.nominal;
    final perMinute = nominal * 60 - dropped;
    final perTenMinutes = nominal * 600 - dropped * 9;

    final tens = frames ~/ perTenMinutes;
    final remainder = frames % perTenMinutes;
    var numbered = frames + dropped * 9 * tens;
    if (remainder > dropped) {
      numbered += dropped * ((remainder - dropped) ~/ perMinute);
    }
    return numbered;
  }

  static int _framesFromFields(
    int hours,
    int minutes,
    int seconds,
    int frames,
    FrameRate rate,
    bool dropFrame,
  ) {
    final nominal = rate.nominal;
    final numbered =
        nominal * 3600 * hours +
        nominal * 60 * minutes +
        nominal * seconds +
        frames;
    if (!dropFrame || !rate.supportsDropFrame) return numbered;

    final totalMinutes = hours * 60 + minutes;
    return numbered -
        rate.droppedPerMinute * (totalMinutes - totalMinutes ~/ 10);
  }

  @override
  bool operator ==(Object other) =>
      other is Timecode &&
      other.frame == frame &&
      other.rate == rate &&
      other._isDrop == _isDrop;

  @override
  int get hashCode => Object.hash(frame, rate, _isDrop);

  @override
  String toString() => format();
}
