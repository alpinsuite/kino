/// The models and paths the application is built on.
///
/// Depends on `flutter/foundation` for change notification and on `dart:io` for
/// the filesystem, and on nothing in the widget layer — `tools/check_layer_
/// purity.sh` enforces that. Anything here can be exercised by a test that
/// never pumps a frame.
library;

export 'src/media_info.dart';
export 'src/media_key.dart';
export 'src/playback_state.dart';
export 'src/xdg.dart';
