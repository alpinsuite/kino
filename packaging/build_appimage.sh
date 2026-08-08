#!/usr/bin/env bash
#
# Packages the release bundle as a single-file AppImage.
#
# Complements the .deb: the AppImage needs no package manager and runs on
# distributions that are not Debian-derived — which is exactly why it has to
# carry libmpv and the FFmpeg libraries with it, and exactly why it carries a
# licensing obligation the .deb does not.
#
# What is bundled and what is not:
#
#   * libmpv, FFmpeg, libass and the rest of the media stack ARE bundled. They
#     are what the distribution cannot be assumed to provide.
#   * glibc, the GTK/GL/X11/Wayland stack and the graphics drivers are NOT.
#     Bundling those is how an AppImage stops working on the machines it was
#     supposed to work on, and hardware decoding needs the host's own drivers.
#
# Because it bundles GPL-licensed binaries, this artefact ships their licences
# and a written offer for the corresponding source. That is generated below into
# usr/share/licenses; docs/LICENSING.md explains the reasoning.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_ID="ch.alpinsuite.Kino"
BUNDLE="build/linux/x64/release/bundle"
VERSION="$(sed -n 's/^version: *\([0-9][^+ ]*\).*/\1/p' pubspec.yaml)"
ARCH="$(uname -m)"

if [[ ! -x "$BUNDLE/kino" ]]; then
  echo "no release bundle at $BUNDLE — run 'flutter build linux --release'" >&2
  exit 1
fi

APPDIR="build/AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" \
         "$APPDIR/usr/share/applications" \
         "$APPDIR/usr/share/metainfo" \
         "$APPDIR/usr/share/icons/hicolor" \
         "$APPDIR/usr/share/licenses"

cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
install -m 644 "packaging/deb/$APP_ID.desktop" \
  "$APPDIR/usr/share/applications/$APP_ID.desktop"
install -m 644 "packaging/deb/$APP_ID.metainfo.xml" \
  "$APPDIR/usr/share/metainfo/$APP_ID.metainfo.xml"

bash packaging/render_icons.sh "build/icons/hicolor"
cp -r build/icons/hicolor/. "$APPDIR/usr/share/icons/hicolor/"

# ---------------------------------------------------------------------------
# The media stack.
# ---------------------------------------------------------------------------

# An allowlist rather than the usual excludelist. An excludelist bundles
# whatever it failed to think of, and the failure mode — a stale libstdc++ or a
# second libGL shadowing the host's — is one that only shows up on someone
# else's machine.
BUNDLE_PATTERN='^lib(mpv|av(codec|format|util|filter|device)|sw(scale|resample)|ass|placebo|shaderc|dav1d|de265|vpx|x264|x265|aom|opus|vorbis|theora|mp3lame|fdk-aac|bluray|dvdnav|dvdread|zimg|rubberband|archive|uchardet|sixel|caca|jpeg|webp|bs2b|lcms2|mujs)'

LIBMPV="$(ldconfig -p 2>/dev/null | awk '/libmpv\.so\.[0-9]/ {print $NF; exit}' || true)"
if [[ -z "$LIBMPV" || ! -e "$LIBMPV" ]]; then
  echo "libmpv was not found by ldconfig — install libmpv2 (or libmpv-dev)" >&2
  exit 1
fi

copy_library() {
  local source="$1"
  local name
  name="$(basename "$source")"
  [[ -e "$APPDIR/usr/lib/$name" ]] && return 0
  cp -L "$source" "$APPDIR/usr/lib/$name"
  chmod 644 "$APPDIR/usr/lib/$name"
  echo "  bundled  $name"
}

copy_library "$LIBMPV"
while read -r library; do
  [[ -e "$library" ]] || continue
  if basename "$library" | grep -qE "$BUNDLE_PATTERN"; then
    copy_library "$library"
  fi
done < <(ldd "$LIBMPV" 2>/dev/null | awk '{print $3}' | grep '^/' | sort -u)

# ---------------------------------------------------------------------------
# Licences and the source offer.
# ---------------------------------------------------------------------------

install -m 644 LICENSE "$APPDIR/usr/share/licenses/LICENSE.Kino.AGPL-3.0.txt"

MANIFEST="$APPDIR/usr/share/licenses/BUNDLED.md"
{
  echo "# Bundled libraries"
  echo
  echo "Kino $VERSION for $ARCH bundles the shared libraries below. Kino itself"
  echo "is AGPL-3.0-or-later; see LICENSE.Kino.AGPL-3.0.txt."
  echo
  echo "| Library | Providing package | Version | Licence |"
  echo "| --- | --- | --- | --- |"
} > "$MANIFEST"

for library in "$APPDIR"/usr/lib/*.so*; do
  name="$(basename "$library")"
  package=""
  version=""
  licences=""
  if command -v dpkg-query > /dev/null 2>&1; then
    package="$(dpkg-query -S "$(readlink -f "/usr/lib/$(uname -m)-linux-gnu/$name" \
      2>/dev/null || echo "$name")" 2>/dev/null | cut -d: -f1 | head -1 || true)"
    if [[ -n "$package" ]]; then
      version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
      licences="$(grep -hoE '^License: *[^ ]+' \
        "/usr/share/doc/$package/copyright" 2>/dev/null |
        sed 's/^License: *//' | sort -u | tr '\n' ' ' || true)"
      # The full text goes in the image, not just the name of it.
      if [[ -f "/usr/share/doc/$package/copyright" ]]; then
        install -m 644 "/usr/share/doc/$package/copyright" \
          "$APPDIR/usr/share/licenses/copyright.$package.txt"
      fi
    fi
  fi
  echo "| $name | ${package:-unknown} | ${version:-unknown} | ${licences:-see copyright file} |" \
    >> "$MANIFEST"
done

cat >> "$MANIFEST" <<OFFER

## Written offer for source

The libraries above are unmodified binaries from the distribution named in the
"Providing package" column, at the version given. Their corresponding source is
available from that distribution's archive, and on request from
<rbuache@gmail.com> for three years from the date of this release.

Kino's own source is at https://github.com/AlpinSuite/kino, tagged v$VERSION.
OFFER

# ---------------------------------------------------------------------------
# AppImage plumbing.
# ---------------------------------------------------------------------------

cp "packaging/deb/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
if [[ -f "build/icons/hicolor/256x256/apps/$APP_ID.png" ]]; then
  cp "build/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"
  cp "build/icons/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/.DirIcon"
else
  cp "packaging/icons/$APP_ID.svg" "$APPDIR/$APP_ID.svg"
  cp "packaging/icons/$APP_ID.svg" "$APPDIR/.DirIcon"
fi

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
# The bundled media stack goes *after* nothing and before the system's, but the
# allowlist above means only libmpv and its own codecs are in here — the GL,
# GTK and driver stack still resolves to the host's, which is what hardware
# decoding needs.
export LD_LIBRARY_PATH="$HERE/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
exec "$HERE/usr/bin/kino" "$@"
APPRUN
chmod 755 "$APPDIR/AppRun"

TOOL="build/appimagetool"
if [[ ! -x "$TOOL" ]]; then
  echo "downloading appimagetool..."
  curl -fsSL -o "$TOOL" \
    "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "$TOOL"
fi

mkdir -p build/dist
OUTPUT="build/dist/Kino-${VERSION}-${ARCH}.AppImage"
# --appimage-extract-and-run avoids needing FUSE, which CI containers lack.
ARCH="$ARCH" "$TOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT"

echo "built $OUTPUT"
echo "bundled licences are listed in usr/share/licenses/BUNDLED.md inside it"
