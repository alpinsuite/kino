#!/usr/bin/env bash
#
# Builds kino_<version>_<arch>.deb from an already-built Flutter bundle.
#
# Run `flutter build linux --release` first, or pass --build to have this script
# do it. The result lands in build/dist/.
#
# This artefact *depends on* the distribution's libmpv rather than bundling one
# (spec §0.3). That is not only smaller: it means the .deb distributes no
# GPL-licensed binary at all, so the source-offer obligation stays with the
# distribution that already meets it. The AppImage is where bundling — and the
# obligation — lives.
#
# Runtime dependencies are computed with dpkg-shlibdeps rather than written by
# hand, so they stay correct as the Flutter engine's and libmpv's own
# dependencies change.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

PACKAGE="kino"
APP_ID="ch.alpinsuite.Kino"
MAINTAINER="${DEB_MAINTAINER:-rbuache <rbuache@gmail.com>}"

BUILD_FIRST=0
for arg in "$@"; do
  case "$arg" in
    --build) BUILD_FIRST=1 ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# Version comes from pubspec.yaml, minus the +build suffix Debian has no use for.
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml)"
if [[ -z "$VERSION" ]]; then
  echo "could not read version from pubspec.yaml" >&2
  exit 1
fi

ARCH="$(dpkg --print-architecture)"
BUNDLE="build/linux/x64/release/bundle"

if [[ "$BUILD_FIRST" == "1" ]]; then
  flutter build linux --release
fi

if [[ ! -x "$BUNDLE/$PACKAGE" ]]; then
  echo "no release bundle at $BUNDLE — run 'flutter build linux --release'" >&2
  exit 1
fi

STAGE="build/deb/${PACKAGE}_${VERSION}_${ARCH}"
rm -rf "$STAGE"
mkdir -p \
  "$STAGE/DEBIAN" \
  "$STAGE/usr/bin" \
  "$STAGE/usr/lib/$PACKAGE" \
  "$STAGE/usr/share/applications" \
  "$STAGE/usr/share/metainfo" \
  "$STAGE/usr/share/doc/$PACKAGE" \
  "$STAGE/usr/share/man/man1"

# The bundle keeps its own layout under /usr/lib/kino; only a launcher goes on
# PATH, which is the convention for self-contained desktop applications.
cp -r "$BUNDLE/." "$STAGE/usr/lib/$PACKAGE/"
chmod 755 "$STAGE/usr/lib/$PACKAGE/$PACKAGE"

cat > "$STAGE/usr/bin/$PACKAGE" <<'LAUNCHER'
#!/bin/sh
# The engine looks for its data and libraries relative to the executable, so it
# has to be invoked from its own directory rather than through a symlink.
exec /usr/lib/kino/kino "$@"
LAUNCHER
chmod 755 "$STAGE/usr/bin/$PACKAGE"

install -m 644 "packaging/deb/$APP_ID.desktop" \
  "$STAGE/usr/share/applications/$APP_ID.desktop"
install -m 644 "packaging/deb/$APP_ID.metainfo.xml" \
  "$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"

bash packaging/render_icons.sh "build/icons/hicolor"
mkdir -p "$STAGE/usr/share/icons"
cp -r "build/icons/hicolor" "$STAGE/usr/share/icons/"

install -m 644 LICENSE "$STAGE/usr/share/doc/$PACKAGE/copyright"
gzip -9nc packaging/deb/kino.1 > "$STAGE/usr/share/man/man1/$PACKAGE.1.gz"
gzip -9nc CHANGELOG.md > "$STAGE/usr/share/doc/$PACKAGE/changelog.gz"

INSTALLED_SIZE="$(du -ks "$STAGE" | cut -f1)"

cat > "$STAGE/DEBIAN/control" <<CONTROL
Package: $PACKAGE
Version: $VERSION
Section: video
Priority: optional
Architecture: $ARCH
Maintainer: $MAINTAINER
Installed-Size: $INSTALLED_SIZE
Homepage: https://github.com/AlpinSuite/kino
Description: video player and review tool
 Kino is a video player for the Linux desktop. It opens a file, plays it
 correctly, and stays out of the way. Playback is libmpv, so every format
 FFmpeg understands works, hardware decoding is on by default with a clean
 fall back to software, and subtitles render through libass.
 .
 It also does something no other Linux player does well: review. Frame-exact
 stepping and seeking, SMPTE timecode, in and out marks, and timestamped notes
 that attach to a frame rather than to an approximate second, exported as CSV,
 Markdown or PDF for someone else to act on.
 .
 No accounts, no telemetry, no media library, and no network access.
CONTROL

# dpkg-shlibdeps reads the ELF binaries and reports exactly what they link
# against. It must run from the staging root and needs a control file to exist.
DEPENDS=""
if command -v dpkg-shlibdeps > /dev/null 2>&1; then
  mkdir -p "$STAGE/debian"
  touch "$STAGE/debian/control"
  (
    cd "$STAGE"
    # The bundled Flutter engine libraries are shipped in the package itself, so
    # point the resolver at them instead of letting it fail on an unpackaged
    # path.
    LD_LIBRARY_PATH="usr/lib/$PACKAGE/lib:${LD_LIBRARY_PATH:-}" \
      dpkg-shlibdeps -O --ignore-missing-info \
        "usr/lib/$PACKAGE/$PACKAGE" "usr/lib/$PACKAGE/lib/"*.so 2> shlibdeps.log \
        > shlibdeps.out || true
  )
  DEPENDS="$(sed -n 's/^shlibs:Depends=//p' "$STAGE/shlibdeps.out" 2>/dev/null || true)"
  rm -rf "$STAGE/debian" "$STAGE/shlibdeps.out" "$STAGE/shlibdeps.log"
fi

# Fall back to the known-good minimum when shlibdeps is unavailable (for
# instance on a non-Debian build host).
if [[ -z "$DEPENDS" ]]; then
  DEPENDS="libc6, libgtk-3-0, libglib2.0-0, libstdc++6, zlib1g, libmpv2 | libmpv1"
  echo "warning: dpkg-shlibdeps produced nothing; using the fallback list" >&2
fi

# libmpv has to be declared by hand, and this is not a workaround.
#
# media_kit does not link libmpv — it dlopen()s it, trying libmpv.so, then
# .so.2, then .so.1. Nothing about that appears in the ELF, so dpkg-shlibdeps
# cannot see the dependency that makes this a video player rather than a window
# that opens and plays nothing.
#
# The alternative is what makes one .deb installable across the range: Ubuntu
# 22.04 and Debian 12 ship libmpv1, 24.04 and Debian 13 ship libmpv2, and
# because the choice is made at runtime the same binary satisfies both. A
# build-time link would have frozen whichever SONAME the build container had.
if ! printf '%s' "$DEPENDS" | grep -q 'libmpv'; then
  DEPENDS="$DEPENDS, libmpv2 | libmpv1"
fi
echo "Depends: $DEPENDS" >> "$STAGE/DEBIAN/control"

# VA-API and its drivers are what make hardware decoding work at all, but a
# machine with an NVIDIA proprietary stack needs none of them, so they are
# recommendations rather than dependencies.
echo "Recommends: mesa-va-drivers, libva2, libva-drm2" >> "$STAGE/DEBIAN/control"

# Refresh the icon, desktop and MIME caches so the launcher entry appears and
# Kino is offered as a handler without a logout.
cat > "$STAGE/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if [ "$1" = "configure" ]; then
  if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
  fi
fi
POSTINST

cat > "$STAGE/DEBIAN/postrm" <<'POSTRM'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "purge" ]; then
  if command -v update-desktop-database > /dev/null 2>&1; then
    update-desktop-database -q /usr/share/applications || true
  fi
  if command -v gtk-update-icon-cache > /dev/null 2>&1; then
    gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
  fi
fi
POSTRM

chmod 755 "$STAGE/DEBIAN/postinst" "$STAGE/DEBIAN/postrm"

mkdir -p build/dist
OUTPUT="build/dist/${PACKAGE}_${VERSION}_${ARCH}.deb"
dpkg-deb --root-owner-group --build "$STAGE" "$OUTPUT"

echo "built $OUTPUT"
dpkg-deb --info "$OUTPUT" | sed 's/^/  /'
