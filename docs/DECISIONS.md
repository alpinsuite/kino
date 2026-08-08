# Decisions

Why things are the way they are. Each entry is the reasoning at the time, kept
so a later reader can tell a considered choice from an accident.

## 1. Playback is libmpv through `media_kit`. No engine is written here.

A video pipeline means demuxing, decoding, hardware acceleration across three
vendor stacks, A/V sync, subtitle rendering, colour management and seek
behaviour. mpv has spent fifteen years on precisely that, and every serious
modern player is an mpv frontend — Celluloid on GTK, Haruna on Qt, IINA on
macOS. Flutter's own `video_player` is mobile-first and effectively unsupported
on Linux.

`media_kit` solves the Flutter-specific half: getting decoded frames into the
compositor through the texture registrar without a per-frame CPU copy. That
bridge is the make-or-break piece of any Flutter video player, and
reimplementing it over raw FFI is weeks of work for nothing.

**Consequence:** the interface, review mode and desktop integration are what
this project actually builds.

## 2. `media_kit` is wrapped behind `PlaybackController`, and never escapes.

`packages/kino_media` is the only place that names an mpv property or imports
`media_kit`. `tools/check_layer_purity.sh` fails the build otherwise.

The payoff is concrete rather than architectural: when `media_kit` does not
expose a property, dropping to `dart:ffi` against libmpv — or replacing the
engine outright — stays a change to one package instead of to every widget that
touches playback.

The one deliberate leak is `PlaybackSurface`, which downcasts to reach the
`VideoController`. A texture handle has to get to a widget somehow, and one
documented downcast is cheaper than an engine type on the public interface.

## 3. libmpv is `dlopen`ed, not linked — and that is load-bearing for packaging.

Discovered while writing `build_deb.sh`, not designed: `media_kit` opens
`libmpv.so`, then `libmpv.so.2`, then `libmpv.so.1` at runtime. Two consequences
that would otherwise be surprises:

- `dpkg-shlibdeps` cannot see the dependency, because no SONAME is in the ELF.
  `packaging/build_deb.sh` declares `libmpv2 | libmpv1` by hand, and CI fails
  the build if that declaration goes missing.
- The glibc 2.35 baseline container does **not** freeze the libmpv SONAME. One
  `.deb` built on Ubuntu 22.04 installs and runs on 24.04, where the library is
  called `libmpv.so.2` instead. Had it been linked, it would not.

## 4. AGPL-3.0-or-later, and the `.deb` bundles nothing.

Recorded in full in [LICENSING.md](LICENSING.md). The short version: mpv is
GPL-2.0-**or-later**, the "or later" is what makes an AGPLv3 application lawful,
and it is verified per build by `tools/audit_licenses.sh` rather than assumed
once.

The `.deb` depends on the distribution's libmpv and so distributes no
GPL binary at all. The AppImage necessarily bundles, and therefore carries the
licences and a written source offer inside the image.

## 5. Timecode is frame counts and exact rationals. Never floating-point seconds.

29.97 is not a frame rate; 30000/1001 is. `FrameRate` holds the numerator and
denominator and every conversion is integer arithmetic, because a `double` frame
rate carries a rounding error into every position-to-frame conversion, and over
two hours that error is whole frames — which defeats the point of a
frame-accurate player.

One bug this already caught: `positionOf` originally truncated to the
microsecond, which put the returned position a microsecond *inside the previous
frame*. `frameAt(positionOf(f))` answered `f - 1` for most of the timeline. It
rounds up now, and the test walks every frame of an hour at 29.97 rather than
sampling — a fractional-frame error only becomes a whole frame somewhere in the
middle, which is exactly where sampling misses it.

## 6. Drop-frame timecode is supported, and off by default.

Drop-frame is a renumbering trick that skips two frame *numbers* (four at 59.94)
at the top of every minute except every tenth, so that a timecode's hour matches
an hour of wall clock. No frames are discarded — only their labels.

It is supported because it is cheap in a frame-count model, because it is only
defined for the /1001 rates whose nominal is 30 or 60, and because 29.97 footage
is what a great deal of inspection video actually is.

It is **off by default** because Kino's audience is site inspection and
engineering review, not broadcast delivery — and because a timecode silently
numbered differently from what the reviewer expects is worse than one they had
to switch on. `HH:MM:SS;FF` with a semicolon, per SMPTE, so which mode is in use
is visible rather than inferred.

## 7. Annotation colours are named, not valued.

`AnnotationColor.red`, resolved against the Slate palette by the interface. A
stored `0xFFE04A3F` is a colour that will be wrong in the other theme and
unthemeable forever after.

This is also what lets `kino_review` stay free of `dart:ui` — it could not hold
a `Color` if it wanted to. The constraint and the design agreed, which is
usually a sign the constraint was the right one.

## 8. `kino_review` has no Flutter dependency at all.

Not a style rule. Review mode is the part of this application that has to be
exercised exhaustively — every frame of an hour, every drop-frame boundary, a
merge of two reviewers' passes, a full JSON round trip — and a widget binding in
the dependency graph turns a headless second into a pumped minute.

Enforced by `tools/check_layer_purity.sh`, which also checks the pubspec, since
an unused dependency is a used one waiting to happen.

## 9. Screen-blanking inhibition is Kino's, not `wakelock_plus`'s.

`media_kit_video`'s `Video` widget is built with `wakelock: false`.

The screen must not blank during playback and must blank when paused — an
acceptance criterion, and the single most complained-about bug in every player.
Getting it right needs the Wayland `idle-inhibit-unstable-v1` protocol where
available and `org.freedesktop.ScreenSaver` on X11. `wakelock_plus` covers part
of that, and two inhibitors fighting over one session is how a screen ends up
never blanking at all.

**Status: not yet implemented.** The flag is set so that when it is, there is
nothing to un-wire.

## 10. Multiple windows are allowed; the runner is `G_APPLICATION_NON_UNIQUE`.

Which is the Flutter template's default, and happens to be what the design
wants. The only guard is that opening a file already playing elsewhere should
raise that window — a lock file under `$XDG_RUNTIME_DIR/kino`, not process
arbitration or D-Bus activation.

`XdgPaths.runtimeDir` returns null rather than inventing a directory when
`$XDG_RUNTIME_DIR` is unset. A substitute under `/tmp` would survive a crash and
leave a lock on a file nothing is playing.

## 11. The transport bar is docked, not floating. Provisionally.

§2 of the specification calls for an overlay bar that floats over the video on a
scrim and auto-hides. That needs `scrim`/`overlay` roles in `SlatePalette` —
translucent surfaces with a stated contrast guarantee against moving picture —
which the pinned Slate does not have. It is a kit change, not a local one, and
PDF Ninja will want the same roles for its annotation overlays.

The docked row is the same controls in a shape that needs no new palette roles.
It is replaced wholesale by `SlateOverlayBar` when that lands, along with the
media icon set.

`slate_ui` v0.2.0 added 24 glyphs — `folder` among them, so the empty state's
open button has its icon — but **neither the `scrim`/`overlay` roles nor any
media glyph** (play, pause, stop, previous, next, frame-step, volume, subtitles,
fullscreen, mark-in, mark-out). Both are still outstanding upstream, and the
transport buttons carry labels until they land.

## 12. XDG paths are POSIX-context, and the environment is injected.

`XdgPaths` uses an explicit `path.Context(style: path.Style.posix)` rather than
the host's style, and takes its environment as a parameter. Kino only ever runs
on Linux; pinning the style is what lets these paths be asserted from a test on
any machine, and injecting the environment is what stops a test writing into the
developer's own home directory.

The same reasoning applies to `Uri.file(..., windows: false)` in
`parseArguments`: a colon is a legal character in a POSIX filename, and
`2026-08-07 14:12.mkv` is what a camera writes.

## Still open

- **Position-advances and seek-lands-within-a-frame assertions in CI.** The
  smoke test currently proves a picture reached the compositor; the numeric
  assertions need the `integration_test` harness, which comes with the
  `media_kit` bring-up.
- **Whether the AppImage's bundled-library manifest resolves every `.so` to a
  package.** See the open questions in [LICENSING.md](LICENSING.md).
- **Resume threshold semantics** — how close to the end counts as "watched".
