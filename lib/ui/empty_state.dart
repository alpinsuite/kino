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
    this.engineFailure,
    super.key,
  });

  final VoidCallback onOpen;

  /// Most recent first. Rendered as a plain list; there is no library here and
  /// there is not going to be one (spec §5).
  final List<Uri> recent;

  /// Why libmpv could not be loaded, or null. When set, this panel becomes the
  /// explanation: opening a file would achieve nothing, so the action goes away
  /// rather than sitting there failing silently.
  final Object? engineFailure;

  @override
  Widget build(BuildContext context) {
    final theme = context.slate;
    final strings = AppLocalizations.of(context);

    if (engineFailure != null) {
      return ColoredBox(
        color: theme.palette.background,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  strings.errorEngineUnavailable,
                  textAlign: TextAlign.center,
                  style: theme.titleStyle.copyWith(color: theme.palette.danger),
                ),
                SizedBox(height: theme.metrics.gap),
                Text(
                  strings.errorEngineUnavailableHint,
                  textAlign: TextAlign.center,
                  style: theme.textStyle,
                ),
                SizedBox(height: theme.metrics.gap * 2),
                // The engine's own words. Not translated on purpose: it is the
                // string a user will paste into a search or a bug report.
                Text(
                  '$engineFailure',
                  textAlign: TextAlign.center,
                  style: theme.dimTextStyle,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: theme.palette.background,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SlateButton(
                label: strings.emptyStateOpen,
                icon: SlateIcons.folder,
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
