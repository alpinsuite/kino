import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// Identifies a file by what is in it, not by where it is (spec §1).
///
/// Resume positions and annotation sidecars are both keyed by this, so a file
/// that is renamed, moved to another disk or re-downloaded to a different path
/// keeps everything attached to it. Keying by path loses all of that the first
/// time someone tidies a directory.
///
/// The digest covers the first and last 64 KiB plus the length. Hashing four
/// gigabytes to decide where to resume would take longer than watching the
/// film; hashing only the head would collide across a set of episodes that
/// share a container header and a leader, which is exactly the case this has to
/// get right.
@immutable
class MediaKey {
  const MediaKey(this.value);

  static const int _windowBytes = 64 * 1024;
  static const String _prefix = 'sha256';

  final String value;

  static Future<MediaKey> ofFile(File file) async {
    final length = await file.length();
    final handle = await file.open();
    try {
      final head = await handle.read(
        length < _windowBytes ? length : _windowBytes,
      );
      List<int> tail = const <int>[];
      if (length > _windowBytes * 2) {
        await handle.setPosition(length - _windowBytes);
        tail = await handle.read(_windowBytes);
      }
      return MediaKey.of(length: length, head: head, tail: tail);
    } finally {
      await handle.close();
    }
  }

  /// Visible for testing, and for the day a network stream can supply its own
  /// range reads.
  @visibleForTesting
  static MediaKey of({
    required int length,
    required List<int> head,
    required List<int> tail,
  }) {
    // The length goes in as bytes, not as text, and first: two files that share
    // both windows but differ in size must not share a key. At most 128 KiB is
    // buffered, so building one list costs nothing worth streaming to avoid.
    final digest = sha256.convert(<int>[
      ..._lengthBytes(length),
      ...head,
      ...tail,
    ]);
    return MediaKey('$_prefix:$digest');
  }

  static List<int> _lengthBytes(int length) {
    final bytes = List<int>.filled(8, 0);
    var remaining = length;
    for (var index = 7; index >= 0; index--) {
      bytes[index] = remaining & 0xFF;
      remaining >>= 8;
    }
    return bytes;
  }

  /// The sidecar that sits next to the media, when the directory is writable.
  static String sidecarNameFor(String mediaPath) => '$mediaPath.kino.json';

  @override
  bool operator ==(Object other) => other is MediaKey && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
