# Architecture

## Layers

```
lib/                    the application — views, wiring, l10n
  core/                 theme, version
  ui/                   widgets
packages/
  kino_media/           PlaybackController + the media_kit implementation
  kino_core/            playback state, media description, XDG paths, media keys
  kino_review/          timecode, marks, annotations, sidecar, export
```

Dependencies run one way and only one way:

```
lib  ->  kino_media  ->  kino_core  ->  kino_review
 └────────────────────────┴───────────────┘
```

`slate_ui` sits beside all of it and depends on nothing here, by construction.

`tools/check_layer_purity.sh` enforces the parts that matter, and runs in CI:

| Rule | Why |
|---|---|
| `kino_review` imports no Flutter, and declares no flutter dependency | It has to be exhaustively testable headless |
| `media_kit` appears only inside `kino_media/lib` | So the engine can be replaced, or reached by FFI, without touching the app |
| `kino_core` imports no widget library | Models that know about widgets cannot be tested without one |
| Nothing under `packages/` imports `package:kino` | Dependencies run one way |
| Every `lib/src/*.dart` is exported exactly once | The entrypoint is the whole public surface |

## `kino_review` — the part the product is for

Pure Dart. No Flutter, no `dart:io`, no ambient clock. The rule that shapes it:
**positions are frame counts, never floating-point seconds.**

- `FrameRate` — an exact rational. 30000/1001, not 29.97. Converts between
  `Duration` and frame index with integer arithmetic in both directions.
- `Timecode` — a frame index plus a rendering. SMPTE `HH:MM:SS:FF`, drop-frame
  `HH:MM:SS;FF`, or decimal `HH:MM:SS.mmm`. Never locale-formatted.
- `MarkRange` — in and out, either of which may be unset. The out point is
  *inside* the range: a single-frame range is one frame long.
- `Annotation` — a note on a frame, with a UUID, an `Actor` carrying a nullable
  `userId`, UTC timestamps, and vector `DrawingShape`s in normalised
  coordinates.
- `ReviewDocument` — the sidecar. Merges a colleague's pass by id with
  last-write-wins, and rebases frame indexes through the *position* when the
  rate turns out to be different.
- `ReviewExport` — CSV and Markdown. PDF stays in the application layer, since
  it needs a page and a composited still.

The sidecar shape follows FluidPlan's conventions on purpose. If annotations
ever need to attach to a FluidPlan task, the groundwork cost nothing today.

## `kino_core`

`flutter/foundation` and `dart:io`, no widgets.

- `PlaybackState` — one immutable snapshot. A value rather than a bag of
  notifiers, because the transport bar, the track bar, the status bar and MPRIS
  all have to agree, and they cannot disagree about one object.
- `MediaInfo`, `MediaTrack`, `Chapter`, `VideoFormat` — what the engine found.
- `MediaKey` — content-addressed identity: SHA-256 over the length, the first
  64 KiB and the last 64 KiB. Resume positions and sidecars are keyed by this,
  so a renamed or moved file keeps both.
- `XdgPaths` — config, data, cache and runtime directories. Never `~/.kino`.

## `kino_media`

The wall around the engine. `PlaybackController` is the interface the
application programs against; `MediaKitPlaybackController` is libmpv behind it;
`PlaybackSurface` is the one widget allowed to know which is which.

Where `media_kit` models something, its model is used. Where it does not —
frame stepping, exact seeking, subtitle and audio delay, `volume-max`, the
hardware-decoder readout, chapters — the escape hatch is `NativePlayer`'s
`command` / `getProperty` / `setProperty`, which is the documented way in and a
great deal less work than `dart:ffi`.

## `lib/`

Thin on purpose. `AppShell` owns the recent list and the open path and reads
everything else off the controller. Anything that becomes real behaviour — the
playlist, review mode, keyboard bindings, MPRIS — gets its own controller rather
than accumulating in the shell.

Every user-visible string comes from `AppLocalizations`;
`tools/check_hardcoded_strings.sh` fails the build on a literal in a `Text`.
Every colour and size comes from the Slate theme.
