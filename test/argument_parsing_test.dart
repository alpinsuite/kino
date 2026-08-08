import 'package:flutter_test/flutter_test.dart';
import 'package:kino/main.dart';

/// Stands in for `File(path).absolute.path`, which answers differently on a
/// developer's Windows machine than on the only platform Kino ships to.
String _underCwd(String path) => '/srv/footage/$path';

List<Uri> _parse(List<String> arguments) =>
    parseArguments(arguments, resolve: _underCwd);

void main() {
  group('parseArguments', () {
    test('keeps http and https URLs as they are', () {
      expect(_parse(<String>['https://example.org/clip.mp4']), <Uri>[
        Uri.parse('https://example.org/clip.mp4'),
      ]);
    });

    test('keeps a file: URL, which is what the file manager passes', () {
      expect(_parse(<String>['file:///srv/footage/north%20face.mkv']), <Uri>[
        Uri.parse('file:///srv/footage/north%20face.mkv'),
      ]);
    });

    test('turns a relative path into an absolute file URL', () {
      final parsed = _parse(<String>['clip.mkv']).single;
      expect(parsed.isScheme('file'), isTrue);
      expect(parsed.path, '/srv/footage/clip.mkv');
    });

    test('does not mistake a bare path for a URI with a scheme', () {
      // `Uri.parse('C:/x')` reads `C` as a scheme, and a path containing a
      // colon is not exotic — `2026-08-07 14:12.mkv` is what a camera writes.
      final parsed = _parse(<String>['2026-08-07 14:12.mkv']).single;
      expect(parsed.isScheme('file'), isTrue);
      expect(parsed.pathSegments.last, '2026-08-07 14:12.mkv');
    });

    test('takes several files in order, as %U hands them over', () {
      final playlist = _parse(<String>['a.mkv', 'b.mkv', 'c.mkv']);
      expect(playlist, hasLength(3));
      expect(playlist.map((uri) => uri.pathSegments.last), <String>[
        'a.mkv',
        'b.mkv',
        'c.mkv',
      ]);
    });

    test('ignores flags and empty arguments', () {
      expect(_parse(<String>['--fullscreen', '', '-v']), isEmpty);
    });
  });
}
