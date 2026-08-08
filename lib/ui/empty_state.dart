import 'package:flutter/widgets.dart';
import 'package:slate_ui/slate_ui.dart';

import '../l10n/generated/app_localizations.dart';

/// What Kino shows before a file is open.
///
/// A quiet panel, not a splash screen with a logo in it. The window has just
/// been opened by someone who wants to watch something; the only useful things
/// on screen are the way to open it and the list of what they watched last.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.onOpen,
    this.recent = const <Uri>[],
    super.key,
  });

  final VoidCallback onOpen;

  /// Most recent first. Rendered as a plain list; there is no library here and
  /// there is not going to be one (spec §5).
  final List<Uri> recent;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final strings = AppLocalizations.of(context);

    return ColoredBox(
      color: theme.palette.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // No icon: the pinned Slate has no folder glyph, and the media
              // and file icons this application needs are a contribution to
              // the kit rather than something to draw locally (spec §0.4).
              SlateButton(
                label: strings.emptyStateOpen,
                kind: SlateButtonKind.primary,
                onPressed: onOpen,
              ),
              SizedBox(height: theme.metrics.gap),
              Text(
                strings.emptyStateDropHint,
                textAlign: TextAlign.center,
                style: theme.dimTextStyle,
              ),
              SizedBox(height: theme.metrics.gap * 3),
              Text(strings.emptyStateRecent, style: theme.sectionStyle),
              SizedBox(height: theme.metrics.gap),
              if (recent.isEmpty)
                Text(strings.emptyStateNoRecent, style: theme.dimTextStyle)
              else
                for (final entry in recent)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: theme.metrics.gap / 2,
                    ),
                    child: Text(
                      _label(entry),
                      overflow: TextOverflow.ellipsis,
                      style: theme.textStyle,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  static String _label(Uri source) {
    if (source.pathSegments.isEmpty) return source.toString();
    final last = source.pathSegments.last;
    return last.isEmpty ? source.toString() : Uri.decodeComponent(last);
  }
}
