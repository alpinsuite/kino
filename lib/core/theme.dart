import 'package:flutter/material.dart';
import 'package:slate_ui/slate_ui.dart';

/// Which palette to draw with.
enum KinoThemeMode {
  /// Follow the desktop. GNOME and KDE both report this through the platform
  /// brightness, so no D-Bus call is needed to honour it.
  system,
  light,
  dark,
}

/// The theme, and the only place a [SlateThemeData] is constructed.
///
/// Defaults to dark and stays there when the desktop says nothing, because this
/// is a video player: a light interface around a dark picture is a lamp pointed
/// at the viewer.
class ThemeController extends ChangeNotifier {
  ThemeController([this._mode = KinoThemeMode.system]);

  KinoThemeMode _mode;
  KinoThemeMode get mode => _mode;

  set mode(KinoThemeMode value) {
    if (value == _mode) return;
    _mode = value;
    notifyListeners();
  }

  /// [platformBrightness] comes from `MediaQuery`, so a change to the desktop
  /// theme repaints without anything here having to watch for it.
  SlateThemeData resolve(Brightness platformBrightness) {
    final dark = switch (_mode) {
      KinoThemeMode.dark => true,
      KinoThemeMode.light => false,
      KinoThemeMode.system => platformBrightness != Brightness.light,
    };
    return dark ? const SlateThemeData.dark() : const SlateThemeData.light();
  }
}
