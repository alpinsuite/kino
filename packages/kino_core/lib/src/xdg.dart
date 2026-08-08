import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

/// POSIX explicitly, not the host's style. Kino only ever runs on Linux, and
/// pinning the context is what lets these paths be asserted from a test running
/// anywhere.
final path.Context _p = path.Context(style: path.Style.posix);

/// Where Kino is allowed to write (spec §0.5).
///
/// Never `~/.kino`. The XDG Base Directory specification is not a suggestion on
/// this desktop: a user who moves `$XDG_CONFIG_HOME` expects their settings to
/// follow, and a backup tool that skips `$XDG_CACHE_HOME` expects the
/// thumbnails to be there and not in the data directory.
///
/// The environment is injected so this is testable without a Linux home
/// directory, and so a test cannot accidentally write into the developer's own.
@immutable
class XdgPaths {
  const XdgPaths({required this.environment});

  /// The real process environment.
  factory XdgPaths.fromPlatform() =>
      XdgPaths(environment: Platform.environment);

  /// Injected rather than read from [Platform] directly, so these paths can be
  /// asserted from a test without a Linux home directory — and so a test cannot
  /// write into the developer's own.
  final Map<String, String> environment;

  /// The reverse-DNS name the data directory is keyed by. Config and cache use
  /// the short binary name, which is the convention for both.
  static const String applicationId = 'ch.alpinsuite.kino';
  static const String applicationName = 'kino';

  String get _home => environment['HOME'] ?? environment['USERPROFILE'] ?? '';

  String _base(String variable, List<String> fallback) {
    final value = environment[variable];
    // A relative path in one of these is invalid per the spec and is ignored,
    // rather than resolved against whatever directory Kino was launched from.
    if (value != null && value.isNotEmpty && _p.isAbsolute(value)) return value;
    return _p.joinAll(<String>[_home, ...fallback]);
  }

  /// `$XDG_CONFIG_HOME/kino` — `settings.json` lives here.
  String get configDir =>
      _p.join(_base('XDG_CONFIG_HOME', <String>['.config']), applicationName);

  /// `~/.local/share/ch.alpinsuite.kino` — sidecars for read-only media,
  /// playlists, the annotation store.
  String get dataDir => _p.join(
    _base('XDG_DATA_HOME', <String>['.local', 'share']),
    applicationId,
  );

  /// `$XDG_CACHE_HOME/kino` — seek-bar thumbnails and resume positions.
  /// Everything here must be safe to delete.
  String get cacheDir =>
      _p.join(_base('XDG_CACHE_HOME', <String>['.cache']), applicationName);

  /// `$XDG_RUNTIME_DIR/kino` — the per-file locks that let opening an
  /// already-playing file raise its window instead of opening a second one.
  ///
  /// Null when the variable is unset, which is a real state on a machine
  /// without a logind session. The caller must degrade to "no lock, open a new
  /// window" rather than inventing a directory: the whole point of
  /// `$XDG_RUNTIME_DIR` is that it is cleaned up at logout, and a substitute in
  /// `/tmp` would leave stale locks behind after a crash.
  String? get runtimeDir {
    final value = environment['XDG_RUNTIME_DIR'];
    if (value == null || value.isEmpty || !_p.isAbsolute(value)) return null;
    return _p.join(value, applicationName);
  }

  String get settingsFile => _p.join(configDir, 'settings.json');

  /// Where a screenshot goes. `user-dirs.dirs` is read because that is where
  /// the desktop records a localised or relocated Pictures directory; a
  /// hardcoded `~/Pictures` is wrong on any non-English install.
  String get picturesDir {
    final configured = _userDir('XDG_PICTURES_DIR');
    return configured ?? _p.join(_home, 'Pictures');
  }

  String? _userDir(String key) {
    final fromEnvironment = environment[key];
    if (fromEnvironment != null && _p.isAbsolute(fromEnvironment)) {
      return fromEnvironment;
    }
    final file = File(_p.join(configDir, '..', 'user-dirs.dirs'));
    if (!file.existsSync()) return null;
    for (final line in file.readAsLinesSync()) {
      final match = RegExp('^$key="(.*)"').firstMatch(line.trim());
      if (match == null) continue;
      return parseUserDir(match.group(1)!, _home);
    }
    return null;
  }

  /// Expands the `"$HOME/Pictures"` form `user-dirs.dirs` uses.
  ///
  /// Visible for testing: the file format is the fiddly part and it is worth
  /// asserting on directly.
  @visibleForTesting
  static String? parseUserDir(String value, String home) {
    if (value.isEmpty) return null;
    if (value.startsWith(r'$HOME')) {
      final rest = value.substring(5);
      return _p.join(home, rest.startsWith('/') ? rest.substring(1) : rest);
    }
    return _p.isAbsolute(value) ? value : null;
  }
}
