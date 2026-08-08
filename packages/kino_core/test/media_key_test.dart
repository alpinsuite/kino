import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kino_core/kino_core.dart';

List<int> _bytes(int length, int seed) =>
    List<int>.generate(length, (index) => (index * 31 + seed) & 0xFF);

void main() {
  group('MediaKey', () {
    test('is stable for the same content', () {
      final first = MediaKey.of(
        length: 1000,
        head: _bytes(64, 1),
        tail: _bytes(64, 2),
      );
      final second = MediaKey.of(
        length: 1000,
        head: _bytes(64, 1),
        tail: _bytes(64, 2),
      );
      expect(first, second);
      expect(first.value, startsWith('sha256:'));
    });

    test('two files sharing both windows but not their length differ', () {
      // The case this exists for: a set of episodes with an identical container
      // header and an identical trailing pad.
      final short = MediaKey.of(
        length: 1000,
        head: _bytes(64, 1),
        tail: _bytes(64, 2),
      );
      final long = MediaKey.of(
        length: 1001,
        head: _bytes(64, 1),
        tail: _bytes(64, 2),
      );
      expect(short, isNot(long));
    });

    test('a difference in either window changes the key', () {
      final base = MediaKey.of(
        length: 10,
        head: _bytes(64, 1),
        tail: _bytes(64, 2),
      );
      expect(
        base,
        isNot(
          MediaKey.of(length: 10, head: _bytes(64, 9), tail: _bytes(64, 2)),
        ),
      );
      expect(
        base,
        isNot(
          MediaKey.of(length: 10, head: _bytes(64, 1), tail: _bytes(64, 9)),
        ),
      );
    });

    test('reads a real file, and does not change when it is renamed', () async {
      final directory = await Directory.systemTemp.createTemp('kino_media_key');
      addTearDown(() => directory.delete(recursive: true));

      final original = File('${directory.path}/walkthrough.mkv');
      await original.writeAsBytes(_bytes(200 * 1024, 7));
      final before = await MediaKey.ofFile(original);

      final renamed = await original.rename('${directory.path}/renamed.mp4');
      expect(await MediaKey.ofFile(renamed), before);
    });

    test('a small file is keyed from its whole content', () async {
      final directory = await Directory.systemTemp.createTemp('kino_media_key');
      addTearDown(() => directory.delete(recursive: true));

      final small = File('${directory.path}/tiny.mp4');
      await small.writeAsBytes(_bytes(10, 3));
      final key = await MediaKey.ofFile(small);

      expect(
        key,
        MediaKey.of(length: 10, head: _bytes(10, 3), tail: const <int>[]),
      );
    });

    test('names the sidecar beside the media', () {
      expect(
        MediaKey.sidecarNameFor('/srv/footage/north-face.mkv'),
        '/srv/footage/north-face.mkv.kino.json',
      );
    });
  });
}
