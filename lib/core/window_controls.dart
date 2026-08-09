import 'package:window_manager/window_manager.dart';

/// The window operations the commands need.
///
/// An interface rather than calls to `windowManager` directly, so the command
/// layer can be tested without a plugin registrar — and so that the one place
/// that talks to the window manager is visible.
abstract class WindowControls {
  Future<bool> isFullScreen();
  Future<void> setFullScreen(bool value);
  Future<void> close();
}

class PlatformWindowControls implements WindowControls {
  const PlatformWindowControls();

  @override
  Future<bool> isFullScreen() => windowManager.isFullScreen();

  @override
  Future<void> setFullScreen(bool value) => windowManager.setFullScreen(value);

  @override
  Future<void> close() => windowManager.close();
}
