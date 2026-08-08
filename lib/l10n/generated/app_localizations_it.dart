// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Kino';

  @override
  String get emptyStateOpen => 'Apri un file';

  @override
  String get emptyStateDropHint => 'oppure trascinane uno sulla finestra';

  @override
  String get emptyStateRecent => 'Recenti';

  @override
  String get emptyStateNoRecent => 'Ancora nulla riprodotto';

  @override
  String get openDialogTitle => 'Apri video';

  @override
  String get openDialogVideoFiles => 'File video';

  @override
  String get transportPlay => 'Riproduci';

  @override
  String get transportPause => 'Pausa';

  @override
  String get transportMute => 'Disattiva audio';

  @override
  String get transportUnmute => 'Attiva audio';

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
    return 'Impossibile aprire $file';
  }
}
