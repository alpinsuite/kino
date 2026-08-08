// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Kino';

  @override
  String get emptyStateOpen => 'Ouvrir un fichier';

  @override
  String get emptyStateDropHint => 'ou déposez-en un sur la fenêtre';

  @override
  String get emptyStateRecent => 'Récents';

  @override
  String get emptyStateNoRecent => 'Rien de lu pour l\'instant';

  @override
  String get openDialogTitle => 'Ouvrir une vidéo';

  @override
  String get openDialogVideoFiles => 'Fichiers vidéo';

  @override
  String get transportPlay => 'Lecture';

  @override
  String get transportPause => 'Pause';

  @override
  String get transportMute => 'Couper le son';

  @override
  String get transportUnmute => 'Rétablir le son';

  @override
  String statusHardwareDecode(String decoder) {
    return 'Matériel · $decoder';
  }

  @override
  String get statusSoftwareDecode => 'Logiciel';

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
    return 'Impossible d\'ouvrir $file';
  }
}
