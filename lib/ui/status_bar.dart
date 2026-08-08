import 'package:flutter/widgets.dart';
import 'package:kino_core/kino_core.dart';
import 'package:slate_ui/slate_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// Resolution, codec, frame rate, and which decoder is doing the work.
///
/// The decoder readout is not a diagnostic nicety: silently falling back to
/// software is the difference between a quiet laptop and a hot one, and §0.6
/// makes "a visible indicator of which is in use" an acceptance criterion.
class StatusBar extends StatelessWidget {
  const StatusBar({required this.state, super.key});

  final PlaybackState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final strings = AppLocalizations.of(context);
    final video = state.media?.video;

    return Container(
      height: theme.metrics.compactRowHeight,
      padding: EdgeInsets.symmetric(horizontal: theme.metrics.pad),
      decoration: BoxDecoration(
        color: theme.palette.panel,
        border: Border(top: BorderSide(color: theme.palette.separator)),
      ),
      child: Row(
        children: <Widget>[
          if (video != null) ...<Widget>[
            _Cell(strings.statusResolution(video.width, video.height)),
            if (video.codec != null) _Cell(video.codec!),
            _Cell(strings.statusFrameRate(_fps(video))),
            _Cell(
              video.hardwareDecoder == null
                  ? strings.statusSoftwareDecode
                  : strings.statusHardwareDecode(video.hardwareDecoder!),
            ),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  /// Two decimals, and never locale-formatted: 29.97 is the name of a rate, not
  /// a quantity the reader is doing arithmetic with.
  static String _fps(VideoFormat video) {
    final rate = video.frameRate;
    return rate.denominator == 1
        ? '${rate.numerator}'
        : rate.asDouble.toStringAsFixed(2);
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    return Padding(
      padding: EdgeInsets.only(right: theme.metrics.gap * 2),
      child: Text(text, style: theme.dimTextStyle),
    );
  }
}
