import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:kino_media/kino_media.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loads libmpv and registers the texture bridge. Must happen before any
  // controller is built and before the first frame.
  //
  // Deliberately not fatal. libmpv is resolved at runtime, so a correctly built
  // Kino can meet a machine that does not have it — the portable tarball cannot
  // declare the dependency the way the .deb does. Letting the failure escape
  // here kills the process before runApp: no window, no message, nothing for
  // the user to search for. The interface opens and explains instead.
  final engineFailure = MediaKitPlaybackController.ensureInitialized();

  await windowManager.ensureInitialized();
  await windowManager.waitUntilReadyToShow(
    const WindowOptions(
      title: 'Kino',
      size: Size(1120, 690),
      // Below this the transport bar starts eliding controls, and a video
      // player nobody can pause is not a smaller video player.
      minimumSize: Size(600, 380),
      center: true,
    ),
    windowManager.show,
  );

  runApp(
    KinoApp(
      initialPlaylist: parseArguments(arguments),
      engineFailure: engineFailure,
    ),
  );
}

/// Turns `%U` from the desktop entry, and anything typed on a shell, into a
/// playlist.
///
/// Both paths and URLs arrive here (spec §0.5), and a bare relative path is not
/// a URI — `Uri.parse` reads everything before the first colon as a scheme, and
/// `2026-08-07 14:12.mkv` is what a camera writes. Anything that is not an
/// absolute `http(s)` or `file` URL is therefore treated as a filesystem path.
///
/// [resolve] makes the one host-dependent step injectable, so the classifying
/// above it can be asserted from a test running anywhere.
@visibleForTesting
List<Uri> parseArguments(
  List<String> arguments, {
  String Function(String path)? resolve,
}) {
  final absolute = resolve ?? (path) => File(path).absolute.path;
  final playlist = <Uri>[];

  for (final argument in arguments) {
    if (argument.isEmpty || argument.startsWith('-')) continue;

    final parsed = Uri.tryParse(argument);
    if (parsed != null &&
        (parsed.isScheme('http') ||
            parsed.isScheme('https') ||
            parsed.isScheme('file'))) {
      playlist.add(parsed);
      continue;
    }
    // `windows: false` because Kino runs on Linux and nowhere else: a colon is
    // a legal character in a POSIX filename, and the Windows rules this would
    // otherwise pick up on a developer's machine reject it outright.
    playlist.add(Uri.file(absolute(argument), windows: false));
  }
  return playlist;
}
