// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kino';

  @override
  String get emptyStateOpen => 'Open a file';

  @override
  String get emptyStateDropHint => 'or drop one onto the window';

  @override
  String get emptyStateRecent => 'Recent';

  @override
  String get emptyStateNoRecent => 'Nothing played yet';

  @override
  String get openDialogTitle => 'Open video';

  @override
  String get openDialogVideoFiles => 'Video files';

  @override
  String get transportPlay => 'Play';

  @override
  String get transportPause => 'Pause';

  @override
  String get transportMute => 'Mute';

  @override
  String get transportUnmute => 'Unmute';

  @override
  String statusHardwareDecode(String decoder) {
    return 'Hardware · $decoder';
  }

  @override
  String get statusSoftwareDecode => 'Software';

  @override
  String statusResolution(int width, int height) {
    return '$width×$height';
  }

  @override
  String statusFrameRate(String fps) {
    return '$fps fps';
  }

  @override
  String errorCouldNotOpen(String file) {
    return 'Could not open $file';
  }
}
