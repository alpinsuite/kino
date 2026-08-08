import 'package:flutter/widgets.dart';
import 'package:kino_core/kino_core.dart';
import 'package:kino_review/kino_review.dart';
import 'package:slate_ui/slate_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// The provisional transport row.
///
/// Docked below the video rather than floating over it, and without the
/// auto-hide behaviour §2 describes, because the overlay version needs the
/// `scrim` palette roles that Slate does not have yet — a translucent surface
/// with a stated contrast guarantee against moving picture is a kit change, not
/// a local one. This row is the same controls in a shape that does not need
/// them, and is replaced wholesale by `SlateOverlayBar` once that lands.
/// See docs/DECISIONS.md.
class TransportBar extends StatelessWidget {
  const TransportBar({
    required this.state,
    required this.onPlayOrPause,
    required this.onSeek,
    required this.onVolume,
    required this.onToggleMute,
    super.key,
  });

  final PlaybackState state;
  final VoidCallback onPlayOrPause;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<int> onVolume;
  final VoidCallback onToggleMute;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final strings = AppLocalizations.of(context);
    final enabled = state.hasMedia;

    return Container(
      height: theme.metrics.barHeight,
      padding: EdgeInsets.symmetric(horizontal: theme.metrics.pad),
      decoration: BoxDecoration(
        color: theme.palette.panel,
        border: Border(top: BorderSide(color: theme.palette.separator)),
      ),
      child: Row(
        children: <Widget>[
          SlateButton(
            label: state.isPlaying
                ? strings.transportPause
                : strings.transportPlay,
            onPressed: enabled ? onPlayOrPause : null,
          ),
          SizedBox(width: theme.metrics.gap),
          Text(_timecode(state.position), style: theme.textStyle),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.metrics.gap),
              child: _SeekBar(
                progress: state.progress,
                onSeek: enabled
                    ? (fraction) => onSeek(
                        Duration(
                          microseconds:
                              (state.duration.inMicroseconds * fraction)
                                  .round(),
                        ),
                      )
                    : null,
              ),
            ),
          ),
          Text(_timecode(state.duration), style: theme.dimTextStyle),
          SizedBox(width: theme.metrics.gap),
          SlateButton(
            label: state.muted
                ? strings.transportUnmute
                : strings.transportMute,
            onPressed: enabled ? onToggleMute : null,
          ),
          SizedBox(width: theme.metrics.gap),
          SlateSlider(
            value: state.volume.toDouble(),
            min: 0,
            max: PlaybackState.maxVolume.toDouble(),
            onChanged: (value) => onVolume(value.round()),
          ),
        ],
      ),
    );
  }

  /// Decimal rather than SMPTE here: the transport bar addresses an instant,
  /// and a frame number only means something once review mode is on. Either
  /// way it is never locale-formatted (spec §0.6).
  static String _timecode(Duration position) =>
      Timecode.formatDuration(position);
}

/// A bare track: played range, remainder, and a drag to seek.
///
/// Chapter ticks, the buffered range, review pips and the hover thumbnail all
/// belong to `SlateTrackBar` upstream (spec §0.4); this is the placeholder that
/// lets the window be used in the meantime.
class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.progress, required this.onSeek});

  final double progress;
  final ValueChanged<double>? onSeek;

  @override
  Widget build(BuildContext context) {
    final palette = context.slateColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        void seekTo(Offset local) {
          final fraction = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          onSeek?.call(fraction);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => seekTo(details.localPosition),
          onHorizontalDragUpdate: (details) => seekTo(details.localPosition),
          child: SizedBox(
            height: context.slateMetrics.controlHeight,
            child: Center(
              child: Stack(
                children: <Widget>[
                  Container(height: 3, color: palette.border),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(height: 3, color: palette.accent),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
