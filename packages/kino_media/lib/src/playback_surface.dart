import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_kit_playback_controller.dart';
import 'playback_controller.dart';

/// The video itself.
///
/// The one widget allowed to know which engine is running, and the reason
/// [PlaybackController] can stay free of engine types: the texture handle has
/// to reach a widget somehow, and confining that to a single downcast here is
/// cheaper than threading a `media_kit` type through the interface.
///
/// A controller that is not the `media_kit` one — a fake in a widget test —
/// renders as [fill], so a test can pump a full window without an engine.
class PlaybackSurface extends StatelessWidget {
  const PlaybackSurface({
    required this.controller,
    required this.fill,
    this.fit = BoxFit.contain,
    super.key,
  });

  final PlaybackController controller;

  /// The letterbox. Comes from the caller because every colour in this
  /// application comes from the Slate palette, including this one.
  final Color fill;

  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final engine = controller;
    if (engine is! MediaKitPlaybackController) {
      return ColoredBox(color: fill, child: const SizedBox.expand());
    }
    return Video(
      controller: engine.videoController,
      fit: fit,
      fill: fill,
      // Kino draws its own chrome; media_kit's is a different design language
      // and would sit on top of the Slate overlay bar.
      controls: NoVideoControls,
      // Screen blanking is handled by Kino's own idle inhibit, which speaks the
      // Wayland protocol as well as the X11 one. `wakelock_plus` covers only
      // part of that, and two inhibitors fighting over the same session is how
      // a screen ends up never blanking at all. See docs/DECISIONS.md.
      wakelock: false,
    );
  }
}
