import 'package:meta/meta.dart';

import 'frame_rate.dart';

/// The in and out marks, either of which may be unset.
///
/// Half a range is a normal state, not an error: marking in and then scrubbing
/// for the out point is how the feature is used. The type therefore models
/// "incomplete" rather than refusing to exist until both ends are known.
@immutable
class MarkRange {
  const MarkRange({this.inFrame, this.outFrame});

  static const MarkRange empty = MarkRange();

  final int? inFrame;
  final int? outFrame;

  bool get isEmpty => inFrame == null && outFrame == null;
  bool get isComplete => inFrame != null && outFrame != null;

  /// The first frame of the range, once both ends are set.
  int? get start => isComplete ? _min : null;

  /// The last frame *inside* the range — inclusive, because the out point names
  /// a frame the reviewer wants to see, not the one after it.
  int? get end => isComplete ? _max : null;

  int get _min => inFrame! <= outFrame! ? inFrame! : outFrame!;
  int get _max => inFrame! <= outFrame! ? outFrame! : inFrame!;

  /// Inclusive length: a single-frame range is one frame long.
  int? get lengthInFrames => isComplete ? _max - _min + 1 : null;

  Duration? durationAt(FrameRate rate) {
    final length = lengthInFrames;
    return length == null ? null : rate.positionOf(length);
  }

  bool contains(int frame) => isComplete && frame >= _min && frame <= _max;

  /// Where playback resumes when looping inside the range.
  int? get loopTarget => start;

  MarkRange withIn(int? frame) => MarkRange(inFrame: frame, outFrame: outFrame);
  MarkRange withOut(int? frame) => MarkRange(inFrame: inFrame, outFrame: frame);

  Map<String, Object?> toJson() => <String, Object?>{
    if (inFrame != null) 'in': inFrame,
    if (outFrame != null) 'out': outFrame,
  };

  static MarkRange fromJson(Map<String, Object?> json) => MarkRange(
    inFrame: (json['in'] as num?)?.toInt(),
    outFrame: (json['out'] as num?)?.toInt(),
  );

  @override
  bool operator ==(Object other) =>
      other is MarkRange &&
      other.inFrame == inFrame &&
      other.outFrame == outFrame;

  @override
  int get hashCode => Object.hash(inFrame, outFrame);

  @override
  String toString() => 'MarkRange($inFrame..$outFrame)';
}
