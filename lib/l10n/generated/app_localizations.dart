import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
  ];

  /// The application name. Not translated — it is a proper noun.
  ///
  /// In en, this message translates to:
  /// **'Kino'**
  String get appTitle;

  /// Primary action on the empty state panel.
  ///
  /// In en, this message translates to:
  /// **'Open a file'**
  String get emptyStateOpen;

  /// Secondary hint under the open button on the empty state.
  ///
  /// In en, this message translates to:
  /// **'or drop one onto the window'**
  String get emptyStateDropHint;

  /// Heading above the recent files list on the empty state.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get emptyStateRecent;

  /// Shown in place of the recent files list when it is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing played yet'**
  String get emptyStateNoRecent;

  /// Title of the native file chooser.
  ///
  /// In en, this message translates to:
  /// **'Open video'**
  String get openDialogTitle;

  /// Label of the video file type filter in the file chooser.
  ///
  /// In en, this message translates to:
  /// **'Video files'**
  String get openDialogVideoFiles;

  /// Accessible label of the play button.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get transportPlay;

  /// Accessible label of the pause button.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get transportPause;

  /// Accessible label of the mute button.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get transportMute;

  /// Accessible label of the unmute button.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get transportUnmute;

  /// Status bar indicator naming the active hardware decoder.
  ///
  /// In en, this message translates to:
  /// **'Hardware · {decoder}'**
  String statusHardwareDecode(String decoder);

  /// Status bar indicator when decoding falls back to the CPU.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get statusSoftwareDecode;

  /// Status bar resolution readout.
  ///
  /// In en, this message translates to:
  /// **'{width}×{height}'**
  String statusResolution(int width, int height);

  /// Status bar frame rate readout.
  ///
  /// In en, this message translates to:
  /// **'{fps} fps'**
  String statusFrameRate(String fps);

  /// Headline on the empty state when libmpv could not be loaded.
  ///
  /// In en, this message translates to:
  /// **'Video playback is unavailable'**
  String get errorEngineUnavailable;

  /// Explanation under errorEngineUnavailable, naming the package to install.
  ///
  /// In en, this message translates to:
  /// **'Kino plays video through libmpv, which could not be loaded. Install it — the package is usually called libmpv2 — and start Kino again.'**
  String get errorEngineUnavailableHint;

  /// Shown when the engine refuses a file.
  ///
  /// In en, this message translates to:
  /// **'Could not open {file}'**
  String errorCouldNotOpen(String file);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
