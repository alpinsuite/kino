// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Kino';

  @override
  String get emptyStateOpen => 'Datei öffnen';

  @override
  String get emptyStateDropHint => 'oder eine ins Fenster ziehen';

  @override
  String get emptyStateRecent => 'Zuletzt';

  @override
  String get emptyStateNoRecent => 'Noch nichts abgespielt';

  @override
  String get openDialogTitle => 'Video öffnen';

  @override
  String get openDialogVideoFiles => 'Videodateien';

  @override
  String get transportPlay => 'Wiedergabe';

  @override
  String get transportPause => 'Pause';

  @override
  String get transportMute => 'Stumm';

  @override
  String get transportUnmute => 'Ton ein';

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
    return '$file konnte nicht geöffnet werden';
  }
}
