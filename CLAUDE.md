# CLAUDE.md

Working notes for agents making changes here. Human-facing documentation lives
in [README.md](README.md) and [docs/](docs/); this file is the short version of
what you need before touching the code.

## What this is

A Flutter video player for Linux desktop, built on libmpv through `media_kit`.
Linux only — that is a feature, not a limitation, and it is what buys GTK-native
behaviour, MPRIS, VA-API and proper XDG integration.

The thing that makes it worth building rather than packaging Celluloid is
**review mode**: frame-exact stepping, SMPTE timecode, in/out marks and
timestamped notes exported as CSV, Markdown or PDF. Everything else is table
stakes that make that usable. Read [docs/DECISIONS.md](docs/DECISIONS.md) before
proposing anything structural.

## Environment

The Flutter SDK is **not** preinstalled in a fresh container:

```bash
curl -sSL -o /tmp/flutter.tar.xz \
  https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.8-stable.tar.xz
tar xf /tmp/flutter.tar.xz -C /opt
git config --global --add safe.directory /opt/flutter   # required when running as root
export PATH="/opt/flutter/bin:$PATH"

apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev \
                   build-essential libmpv-dev libepoxy-dev libasound2-dev mpv
```

Four of those are pulled in by `media_kit`'s plugin graph rather than by
Flutter, and a bare container has none of them. Each one, omitted, fails inside
a nested build a long way from anything Flutter prints:

- `libmpv-dev`, `libepoxy-dev` — `media_kit_video`'s CMake links
  `PkgConfig::mpv` and `PkgConfig::epoxy`.
- `libasound2-dev` — `volume_controller`, a transitive dependency, does
  `find_package(ALSA REQUIRED)`.
- `build-essential` — `media_kit_libs_linux` builds mimalloc by shelling out to
  `cmake` with the default generator and then to `make`. Flutter's own build
  uses clang and ninja and never touches either.

The rule of thumb: the Linux build dependencies are `media_kit`'s, not Kino's,
and they are not discoverable from this repository's own source. The
`Verify the native toolchain` CI step asserts every one of them by name for
that reason.

Pin **3.44.8** — it is what CI uses.

## Commands

```bash
flutter pub get
flutter gen-l10n                       # after any change to lib/l10n/app_en.arb
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
bash tools/check_layer_purity.sh
flutter test                           # the application only
(cd packages/kino_review && dart test) # and each package separately
flutter build linux --release          # → build/linux/x64/release/bundle/kino

bash tools/audit_licenses.sh
bash packaging/build_deb.sh --build
bash packaging/build_appimage.sh
tools/set_version.sh                   # print version; pass one to set it
```

The workspace shares one lockfile, but `flutter test` only runs the package it
is invoked in. Run all six checks before claiming a change is done; they are
exactly what the CI analyze job runs, so a green local run means that job is
green. Packaging is a different matter — see
[docs/PACKAGING.md](docs/PACKAGING.md).

## Running the app headlessly

There is no display in the container, but the app runs under Xvfb, and this is
the only way to verify anything about how playback actually behaves:

```bash
apt-get install -y xvfb x11-utils xdotool imagemagick ffmpeg
ffmpeg -f lavfi -i testsrc=size=640x360:rate=25:duration=10 \
       -c:v libx264 -pix_fmt yuv420p /tmp/clip.mp4
nohup Xvfb :99 -screen 0 1400x900x24 -nolisten tcp > /tmp/xvfb.log 2>&1 &
export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=1
cd build/linux/x64/release/bundle && nohup ./kino /tmp/clip.mp4 &
sleep 20                                    # engine init, then libmpv's own
import -display :99 -window root /tmp/shot.png
```

Then read `/tmp/shot.png`. A window that opened but rendered nothing looks
exactly like a working build from the logs, which is why CI checks the
screenshot's standard deviation rather than trusting the exit code.

Never use `pkill -f <pattern>` where the pattern also appears in the command you
are running — it matches your own shell and kills the session.

## Rules that matter

1. **No `media_kit` type appears above `kino_media`.** The application programs
   against `PlaybackController` and `PlaybackSurface`.
   `tools/check_layer_purity.sh` fails the build otherwise. The one deliberate
   downcast is inside `PlaybackSurface`, and it stays the only one.

2. **`kino_review` imports no Flutter, ever.** Not style — it is what keeps a
   two-hour annotation pass a headless second instead of a pumped minute. The
   gate checks the pubspec too.

3. **Positions are frame counts, never floating-point seconds.** Convert at the
   boundary with `FrameRate.frameAt` / `positionOf`, and nowhere else. 29.97 is
   not a frame rate; 30000/1001 is.

4. **`positionOf` rounds up, deliberately.** Truncating puts the returned
   position a microsecond inside the *previous* frame, and every seek lands a
   frame early. There is an exhaustive test over an hour of 29.97; do not
   weaken it to a sample.

5. **Every user-visible string lives in `lib/l10n/app_en.arb`,** with DE, FR and
   IT translations in the same change. Run `flutter gen-l10n` and commit the
   generated files; CI fails when they are stale, and
   `tools/check_hardcoded_strings.sh` fails on a literal in a `Text`.

6. **No colour, size or font literal outside the Slate theme wiring** —
   including in painters and overlays. Annotation colours are named
   (`AnnotationColor.red`), resolved against the palette by the interface, never
   stored as ARGB.

7. **Missing a widget, an icon or a palette role? PR it to
   [alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit), tag, bump the
   pin.** Do not build it locally. The `scrim`/`overlay` roles and the media
   icon set are both outstanding; see decision 11.

8. **libmpv is `dlopen`ed, not linked.** So `dpkg-shlibdeps` cannot see it and
   `packaging/build_deb.sh` declares it by hand. If you touch the dependency
   logic, the CI check that greps `Depends` for `libmpv` is what stops the
   package becoming a window that plays nothing.

9. **Default keybindings match mpv where a sensible equivalent exists.** That
   audience is the first audience. `Esc` always exits fullscreen and never
   quits; `Space` toggles play. Neither is negotiable.

10. **This module refuses scope.** No transcoding, no editing, no media library,
    no casting, no plugins. §5 of the specification is a list of things to say
    no to, and a video player attracts these requests endlessly.

## Gotchas discovered the hard way

- `dart format` reformats aggressively. Anchor-based patch scripts written
  against pre-format source will stop matching — read the file first.
- The pinned `slate_ui` tag usually has a *smaller* icon set than the ui-kit
  working tree. Check the pub cache checkout, or `git show <tag>:lib/src/
  slate_icons.dart`, before using a glyph — not `../ui-kit`. At v0.2.0 there is
  still no media glyph and no `scrim` palette role.
- `Uri.file` applies the *host's* path rules. On a developer's Windows machine
  it rejects a colon that is perfectly legal in a POSIX filename; pass
  `windows: false`. `XdgPaths` pins a POSIX `path.Context` for the same reason.
- `NativePlayer.getProperty` throws for a property that does not apply to the
  current file — a file with no chapters has no `chapter-list/count`. That is
  routine, not an error.
- mpv caps volume at 100 unless `volume-max` is raised, and `media_kit`'s
  `Player.screenshot()` returns bytes rather than writing a file; the
  `screenshot-to-file` command is what honours the subtitles flag.
- `media_kit_video`'s `Video` has its own `wakelock`. It is off on purpose; see
  decision 9.

## Before finishing

- All six checks pass, and every package's tests run.
- New behaviour in `packages/` has tests. `kino_review` especially — it is
  headless and there is no excuse.
- User-visible changes have a `CHANGELOG.md` entry under `## [Unreleased]`.
- A structural choice, or one that surprised you, goes in
  [docs/DECISIONS.md](docs/DECISIONS.md) with its reasoning.
- Do not bump the version in a normal change — releases do that
  ([docs/RELEASING.md](docs/RELEASING.md)).
- Comments explain *why*, never *what*.
