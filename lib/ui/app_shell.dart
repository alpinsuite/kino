import 'dart:async';

import 'package:collection/collection.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:kino_media/kino_media.dart';
import 'package:provider/provider.dart';
import 'package:slate_ui/slate_ui.dart';

import '../l10n/generated/app_localizations.dart';
import 'empty_state.dart';
import 'status_bar.dart';
import 'transport_bar.dart';

/// The window.
///
/// Deliberately thin: it owns the recent list and the open path, and reads
/// everything else off [PlaybackController]. Anything that turns into real
/// behaviour — the playlist, review mode, keyboard bindings — gets its own
/// controller rather than accumulating here.
class AppShell extends StatefulWidget {
  const AppShell({this.initialPlaylist = const <Uri>[], super.key});

  final List<Uri> initialPlaylist;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final List<Uri> _recent = <Uri>[];

  PlaybackController get _playback => context.read<PlaybackController>();

  @override
  void initState() {
    super.initState();
    final first = widget.initialPlaylist.firstOrNull;
    if (first != null) {
      // After the first frame: the engine's texture is not registered until the
      // view exists, and opening before then races it.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(_open(first)),
      );
    }
  }

  Future<void> _open(Uri source) async {
    setState(() {
      _recent
        ..remove(source)
        ..insert(0, source);
      if (_recent.length > 10) _recent.removeLast();
    });
    await _playback.open(source);
  }

  Future<void> _pickFile() async {
    final strings = AppLocalizations.of(context);
    final file = await openFile(
      confirmButtonText: strings.emptyStateOpen,
      acceptedTypeGroups: <XTypeGroup>[
        XTypeGroup(
          label: strings.openDialogVideoFiles,
          // Extensions rather than MIME types: the GTK backend builds a glob
          // filter from these, and a MIME filter would miss a correct file with
          // an unregistered type.
          extensions: const <String>[
            'mp4',
            'mkv',
            'webm',
            'mov',
            'avi',
            'mpg',
            'mpeg',
            'm4v',
            'ts',
            'm2ts',
            'wmv',
            'flv',
            'ogv',
            'm3u8',
          ],
        ),
      ],
    );
    if (file == null) return;
    await _open(Uri.file(file.path));
  }

  @override
  Widget build(BuildContext context) {
    final playback = context.read<PlaybackController>();
    final palette = context.slateColors;

    return DropTarget(
      onDragDone: (details) {
        final first = details.files.firstOrNull;
        if (first != null) unawaited(_open(Uri.file(first.path)));
      },
      child: ListenableBuilder(
        listenable: playback,
        builder: (context, _) {
          final state = playback.state;
          return ColoredBox(
            color: palette.background,
            child: Column(
              children: <Widget>[
                Expanded(
                  child: state.hasMedia
                      ? PlaybackSurface(
                          controller: playback,
                          // The letterbox is a themed surface like any other.
                          fill: palette.background,
                        )
                      : EmptyState(onOpen: _pickFile, recent: _recent),
                ),
                TransportBar(
                  state: state,
                  onPlayOrPause: () => unawaited(playback.playOrPause()),
                  onSeek: (position) => unawaited(playback.seek(position)),
                  onVolume: (volume) => unawaited(playback.setVolume(volume)),
                  onToggleMute: () =>
                      unawaited(playback.setMuted(!state.muted)),
                ),
                StatusBar(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}
