/// The version this build reports.
///
/// Dart cannot read `pubspec.yaml` at runtime, so the value is copied into a
/// constant by `tools/set_version.sh`. The substitution is anchored on the
/// `defaultValue:` line, which must therefore stay on one line.
const String appVersion = String.fromEnvironment(
  'KINO_VERSION',
  defaultValue: '0.1.0',
);
