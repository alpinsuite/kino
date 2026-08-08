#!/usr/bin/env bash
#
# Sets the project version everywhere it appears.
#
#   tools/set_version.sh 1.2.3
#
# pubspec.yaml is the single source of truth; this script propagates that value
# to the AppStream metainfo and to the constant the About dialog reads. The
# Debian control file reads pubspec at build time and needs no editing.
#
# With no argument it prints the current version, which is what CI uses to check
# that a tag matches.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

current_version() {
  sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml
}

if [[ $# -eq 0 ]]; then
  current_version
  exit 0
fi

VERSION="$1"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "not a semantic version: $VERSION" >&2
  echo "expected MAJOR.MINOR.PATCH, optionally with a -prerelease suffix" >&2
  exit 2
fi

# The build number is monotonic across releases; bump it alongside the version
# so package managers never see it go backwards.
BUILD="$(sed -n 's/^version: *[0-9][^+ ]*+\([0-9]*\).*/\1/p' pubspec.yaml)"
BUILD="$(( ${BUILD:-0} + 1 ))"

sed -i "s/^version: .*/version: $VERSION+$BUILD/" pubspec.yaml

# Dart cannot read pubspec at runtime, so the value is copied into a constant.
VERSION_DART="lib/core/app_version.dart"
sed -i "s/  defaultValue: '[^']*',/  defaultValue: '$VERSION',/" "$VERSION_DART"
if ! grep -q "defaultValue: '$VERSION'," "$VERSION_DART"; then
  echo "failed to set the version in $VERSION_DART" >&2
  echo "the defaultValue line must stay on one line for the substitution" >&2
  exit 1
fi

DATE="$(date -u +%Y-%m-%d)"
METAINFO="packaging/deb/ch.alpinsuite.Kino.metainfo.xml"

# Add a release entry unless this version is already listed.
if ! grep -q "version=\"$VERSION\"" "$METAINFO"; then
  python3 - "$METAINFO" "$VERSION" "$DATE" <<'PY'
import sys

path, version, date = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as handle:
    text = handle.read()

entry = (
    f'    <release version="{version}" date="{date}">\n'
    '      <description>\n'
    f'        <p>See the changelog for what changed in {version}.</p>\n'
    '      </description>\n'
    '    </release>\n'
)
text = text.replace('  <releases>\n', '  <releases>\n' + entry, 1)

with open(path, 'w') as handle:
    handle.write(text)
PY
fi

echo "version set to $VERSION (build $BUILD)"
echo
echo "Next steps:"
echo "  1. Move the Unreleased notes in CHANGELOG.md under [$VERSION] - $DATE"
echo "  2. git commit -am \"Release $VERSION\""
echo "  3. git tag -a v$VERSION -m \"Release $VERSION\" && git push --follow-tags"
echo
echo "Pushing the tag builds the packages and publishes the APT repository."
