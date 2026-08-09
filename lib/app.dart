import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kino_media/kino_media.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import 'core/theme.dart';
import 'l10n/generated/app_localizations.dart';
import 'ui/app_shell.dart';

/// Picks the locale to render in, falling back to English.
///
/// Flutter's default resolution returns `supportedLocales.first` when nothing
/// matches, and the generated list is alphabetical — so `de` is first, and a
/// machine with no `LANG` set got a German interface. That is not hypothetical:
/// it is what the CI smoke-test screenshot showed, and it would have been the
/// experience of anyone launching Kino from a bare session or a service.
///
/// Matching is by language code alone. `de_CH` and `de_AT` should both get the
/// German strings rather than falling through to English.
@visibleForTesting
Locale resolveLocale(Locale? requested, Iterable<Locale> supported) {
  if (requested != null) {
    for (final candidate in supported) {
      if (candidate.languageCode == requested.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

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
        // ListenableProvider, not Provider: PlaybackController is a Listenable,
        // and plain Provider asserts against that rather than silently handing
        // out something nothing can rebuild on. The `.value` constructor is
        // right because this State disposes the controller itself.
        ListenableProvider<PlaybackController>.value(value: _playback),
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
            localeResolutionCallback: resolveLocale,
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
