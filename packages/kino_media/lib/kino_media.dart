/// The playback engine, and the wall around it.
///
/// The application depends on [PlaybackController] and on [PlaybackSurface],
/// and on nothing else here. `media_kit` is an implementation detail of this
/// package — `tools/check_layer_purity.sh` fails the build if an import of it
/// appears anywhere above.
library;

export 'src/media_kit_playback_controller.dart';
export 'src/playback_controller.dart';
export 'src/playback_surface.dart';
export 'src/unavailable_playback_controller.dart';
