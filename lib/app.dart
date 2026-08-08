import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kino_media/kino_media.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import 'core/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/app_shell.dart';

class KinoApp extends StatefulWidget {
  const KinoApp({
    this.initialPlaylist = const <Uri>[],
    this.engineFailure,
    super.key,
  });

  /// Files and URLs handed over on the command line, by the file manager, or by
  /// the desktop entry's `%U`.
  final List<Uri> initialPlaylist;

  /// Why libmpv could not be loaded, or null when it did. Non-null means the
  /// window opens on an explanation rather than a player.
  final Object? engineFailure;

  @override
  State<KinoApp> createState() => _KinoAppState();
}

class _KinoAppState extends State<KinoApp> {
  final ThemeController _theme = ThemeController();
  late final PlaybackController _playback = widget.engineFailure == null
      ? MediaKitPlaybackController()
      // Constructing the real controller would throw for the same reason
      // initialisation did, so it is not attempted.
      : UnavailablePlaybackController(widget.engineFailure!);

  @override
  void dispose() {
    // The engine holds a libmpv handle and a texture; leaking either survives
    // the widget tree.
    unawaited(_playback.dispose());
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeController>.value(value: _theme),
        Provider<PlaybackController>.value(value: _playback),
      ],
      child: ListenableBuilder(
        listenable: _theme,
        builder: (context, _) {
          final slate = _theme.resolve(
            MediaQuery.platformBrightnessOf(context),
          );
          return MaterialApp(
            onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            theme: slate.toMaterialTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            // The Slate theme is installed once, above everything, so every
            // widget below reaches it through `context.slate`.
            builder: (context, child) => SlateTheme(
              data: slate,
              child: child ?? const SizedBox.shrink(),
            ),
            home: AppShell(initialPlaylist: widget.initialPlaylist),
          );
        },
      ),
    );
  }
}
