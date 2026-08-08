#!/usr/bin/env bash
#
# Checks that the layers Kino is built out of still point the way they were
# drawn.
#
# Three of these rules are load-bearing rather than tidy:
#
#   * `kino_review` must not import Flutter. Timecode arithmetic, marks and
#     annotations are the part of this application that has to be exercised
#     exhaustively — an hour of frames, every drop-frame boundary, a merge of
#     two reviewers' passes — and a widget binding in the dependency graph turns
#     a headless second into a pumped minute.
#   * `media_kit` must not escape `kino_media`. The whole value of the
#     PlaybackController boundary is that replacing the engine, or dropping to
#     dart:ffi for a property media_kit does not expose, stays a change to one
#     package (spec §0.2).
#   * `kino_core` must not import the widget layer. Models that know about
#     widgets cannot be tested without one.
#
# A rule in a file is checked exactly as often as someone remembers, which is
# why this runs in CI.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Build output and the pub tool cache both sit under packages/, and both are
# full of generated files that mention every import in the program. Grepping
# them turns this gate into a coin toss that fails after any local test run.
SKIP=(--exclude-dir=build --exclude-dir=.dart_tool --exclude-dir=.git)

STATUS=0
fail() {
  echo "  FAIL  $1" >&2
  STATUS=1
}

report() {
  echo "$1" | sed 's/^/          /' >&2
}

echo "Checking that kino_review is free of Flutter..."
REVIEW_IMPORTS="$(
  grep -rhoE "${SKIP[@]}" "^import '[^']+'" packages/kino_review/lib/ |
    sed "s/^import '//; s/'$//" |
    grep -E '^package:flutter' |
    sort -u || true
)"
if [[ -n "$REVIEW_IMPORTS" ]]; then
  fail "packages/kino_review/lib imports Flutter:"
  report "$REVIEW_IMPORTS"
  echo "        Review mode is pure Dart so it can be tested headless." >&2
else
  echo "  ok    no Flutter import"
fi

if grep -qE '^\s+flutter:' packages/kino_review/pubspec.yaml; then
  fail "packages/kino_review/pubspec.yaml declares a flutter dependency"
else
  echo "  ok    no flutter dependency declared"
fi

echo "Checking that media_kit stays inside kino_media..."
ESCAPED="$(
  grep -rlE "${SKIP[@]}" "^import 'package:media_kit" lib/ packages/ 2>/dev/null |
    grep -v '^packages/kino_media/lib/' |
    sort -u || true
)"
if [[ -n "$ESCAPED" ]]; then
  fail "media_kit is imported outside packages/kino_media/lib:"
  report "$ESCAPED"
  echo "        Depend on PlaybackController and PlaybackSurface instead." >&2
else
  echo "  ok    media_kit is confined to kino_media"
fi

echo "Checking that kino_core keeps out of the widget layer..."
WIDGETS="$(
  grep -rhoE "${SKIP[@]}" \
    "^import 'package:flutter/(material|widgets|cupertino)\.dart'" \
    packages/kino_core/lib/ 2>/dev/null | sort -u || true
)"
if [[ -n "$WIDGETS" ]]; then
  fail "packages/kino_core/lib imports the widget layer:"
  report "$WIDGETS"
  echo "        foundation.dart is the most kino_core may reach for." >&2
else
  echo "  ok    foundation only"
fi

echo "Checking that no library imports the application..."
UPWARDS="$(
  grep -rlE "${SKIP[@]}" "^import 'package:kino/" packages/ 2>/dev/null | sort -u || true
)"
if [[ -n "$UPWARDS" ]]; then
  fail "a package under packages/ imports the application:"
  report "$UPWARDS"
  echo "        Dependencies run one way: lib/ -> packages/, never back." >&2
else
  echo "  ok    dependencies run one way"
fi

echo "Checking that every source file is exported by its entrypoint..."
for package in kino_core kino_media kino_review; do
  entrypoint="packages/$package/lib/$package.dart"
  for file in packages/"$package"/lib/src/*.dart; do
    name="$(basename "$file")"
    count="$(grep -c "^export 'src/$name';$" "$entrypoint" || true)"
    if [[ "$count" -eq 0 ]]; then
      fail "$file is not exported by $entrypoint"
    elif [[ "$count" -gt 1 ]]; then
      fail "$file is exported $count times by $entrypoint"
    fi
  done
done
if [[ "$STATUS" -eq 0 ]]; then
  echo "  ok    every source file is exported exactly once"
fi

exit "$STATUS"
