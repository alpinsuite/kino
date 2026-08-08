/// Review mode — the reason Kino exists (spec §7).
///
/// Everything here is pure Dart. No Flutter, no `dart:io`, no clocks and no
/// randomness that the caller cannot supply, which is what makes a two-hour
/// annotation pass something a headless test can assert about.
///
/// The one rule that shapes the whole library: **positions are frame counts,
/// never floating-point seconds.** A `Duration` is converted to a frame index
/// at the boundary ([FrameRate.frameAt]) and back again at the boundary
/// ([FrameRate.positionOf]); in between, an annotation is an integer. Seconds
/// accumulate error, and "the weld is wrong at 04:12" has to survive a round
/// trip through a file and a second reviewer.
library;

export 'src/annotation.dart';
export 'src/frame_rate.dart';
export 'src/mark_range.dart';
export 'src/review_document.dart';
export 'src/review_export.dart';
export 'src/timecode.dart';
export 'src/uuid.dart';
