import 'package:flutter_test/flutter_test.dart';
import 'package:kino_core/kino_core.dart';

XdgPaths _paths([Map<String, String> overrides = const <String, String>{}]) =>
    XdgPaths(
      environment: <String, String>{'HOME': '/home/alice', ...overrides},
    );

void main() {
  group('XdgPaths defaults', () {
    test('falls back to the specified directories', () {
      final paths = _paths();
      expect(paths.configDir, '/home/alice/.config/kino');
      expect(paths.cacheDir, '/home/alice/.cache/kino');
      expect(paths.dataDir, '/home/alice/.local/share/ch.alpinsuite.kino');
      expect(paths.settingsFile, '/home/alice/.config/kino/settings.json');
    });

    test('never uses a dotfile in the home directory', () {
      for (final dir in <String>[
        _paths().configDir,
        _paths().cacheDir,
        _paths().dataDir,
      ]) {
        expect(dir, isNot('/home/alice/.kino'));
      }
    });
  });

  group('XdgPaths overrides', () {
    test('honours the environment', () {
      final paths = _paths(<String, String>{
        'XDG_CONFIG_HOME': '/elsewhere/config',
        'XDG_CACHE_HOME': '/elsewhere/cache',
        'XDG_DATA_HOME': '/elsewhere/data',
      });
      expect(paths.configDir, '/elsewhere/config/kino');
      expect(paths.cacheDir, '/elsewhere/cache/kino');
      expect(paths.dataDir, '/elsewhere/data/ch.alpinsuite.kino');
    });

    test('ignores a relative value, as the specification requires', () {
      final paths = _paths(<String, String>{
        'XDG_CONFIG_HOME': 'relative/path',
      });
      expect(paths.configDir, '/home/alice/.config/kino');
    });

    test('ignores an empty value', () {
      final paths = _paths(<String, String>{'XDG_DATA_HOME': ''});
      expect(paths.dataDir, '/home/alice/.local/share/ch.alpinsuite.kino');
    });
  });

  group('runtimeDir', () {
    test('is the lock directory when a session provides one', () {
      final paths = _paths(<String, String>{
        'XDG_RUNTIME_DIR': '/run/user/1000',
      });
      expect(paths.runtimeDir, '/run/user/1000/kino');
    });

    test('is null rather than invented when there is no session', () {
      // The caller degrades to "open a new window"; a substitute under /tmp
      // would survive a crash and lock a file nothing is playing.
      expect(_paths().runtimeDir, isNull);
      expect(
        _paths(<String, String>{'XDG_RUNTIME_DIR': ''}).runtimeDir,
        isNull,
      );
    });
  });

  group('picturesDir', () {
    test('prefers the environment when the desktop exports it', () {
      final paths = _paths(<String, String>{
        'XDG_PICTURES_DIR': '/home/alice/Bilder',
      });
      expect(paths.picturesDir, '/home/alice/Bilder');
    });

    test('falls back to ~/Pictures', () {
      expect(_paths().picturesDir, '/home/alice/Pictures');
    });

    test('expands the \$HOME form used by user-dirs.dirs', () {
      expect(
        XdgPaths.parseUserDir(r'$HOME/Bilder', '/home/alice'),
        '/home/alice/Bilder',
      );
      expect(
        XdgPaths.parseUserDir('/mnt/photos', '/home/alice'),
        '/mnt/photos',
      );
      // An empty value means "this directory is disabled", not "the home
      // directory", which is what a naive join would produce.
      expect(XdgPaths.parseUserDir('', '/home/alice'), isNull);
      expect(XdgPaths.parseUserDir('Bilder', '/home/alice'), isNull);
    });
  });
}
