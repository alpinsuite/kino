#!/usr/bin/env bash
#
# Renders the hicolor PNG sizes from the one scalable source.
#
# The SVG is the only icon committed. Rendering at build time rather than
# checking in nine PNGs means the mark cannot drift between sizes, and means a
# change to it is a diff a human can read.
#
#   bash packaging/render_icons.sh [output-root]
#
# Requires rsvg-convert (librsvg2-bin) or inkscape. Without either, the scalable
# icon alone is installed: GNOME and KDE both render it, and only the AppImage's
# root icon really wants a raster.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

APP_ID="ch.alpinsuite.Kino"
SOURCE="packaging/icons/$APP_ID.svg"
OUTPUT="${1:-build/icons/hicolor}"
SIZES=(16 24 32 48 64 128 256 512)

mkdir -p "$OUTPUT/scalable/apps"
install -m 644 "$SOURCE" "$OUTPUT/scalable/apps/$APP_ID.svg"

render() {
  local size="$1" target="$2"
  if command -v rsvg-convert > /dev/null 2>&1; then
    rsvg-convert -w "$size" -h "$size" -o "$target" "$SOURCE"
  elif command -v inkscape > /dev/null 2>&1; then
    inkscape "$SOURCE" -w "$size" -h "$size" -o "$target" > /dev/null 2>&1
  else
    return 1
  fi
}

if ! command -v rsvg-convert > /dev/null 2>&1 &&
   ! command -v inkscape > /dev/null 2>&1; then
  echo "warning: no rsvg-convert or inkscape; shipping the scalable icon only" >&2
  exit 0
fi

for size in "${SIZES[@]}"; do
  mkdir -p "$OUTPUT/${size}x${size}/apps"
  render "$size" "$OUTPUT/${size}x${size}/apps/$APP_ID.png"
done

echo "rendered ${#SIZES[@]} icon sizes into $OUTPUT"
