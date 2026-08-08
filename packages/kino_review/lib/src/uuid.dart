import 'dart:math';

/// RFC 4122 version 4 identifiers.
///
/// Hand-rolled rather than pulled from a package because this library's whole
/// value is that it depends on nothing — thirty lines is a cheaper price than a
/// transitive dependency in the one package that has to stay liftable.
///
/// The generator is injectable so a test can produce a stable document.
abstract final class Uuid {
  static final Random _entropy = Random.secure();

  static String v4([Random? random]) {
    final source = random ?? _entropy;
    final bytes = List<int>.generate(16, (_) => source.nextInt(256));

    // Version 4, variant 1 — the two fields RFC 4122 fixes.
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}'
        '-${hex.substring(12, 16)}-${hex.substring(16, 20)}'
        '-${hex.substring(20)}';
  }
}
