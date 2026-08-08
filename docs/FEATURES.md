# Features

Status against the build specification. `·` not started, `~` partial, `✓` done.

## Foundation

| | |
|---|---|
| ✓ | Repo scaffold, workspace, three packages, layer-purity gate |
| ✓ | AGPL-3.0 licence graph settled and documented ([LICENSING.md](LICENSING.md)) |
| ✓ | CI: format, analyze, l10n staleness, both gates, tests, licence audit |
| ✓ | Packaging: `.deb`, AppImage, APT repo, AppStream, desktop entry, man page |
| ✓ | Slate pinned to `v0.1.0` and installed once above the tree |
| ✓ | i18n wiring with DE, FR, IT, EN |
| ✓ | CI green end to end: build, licence audit, headless playback, `.deb` build, install |
| ~ | Playback smoke test — proves picture reaches the compositor; position and seek assertions pending the `integration_test` harness |

### What the green CI run does and does not prove

Build order step 2 is *partly* discharged. Proven on Ubuntu 22.04, X11:

- `flutter build linux --release` compiles with `media_kit`.
- A generated clip plays headlessly and renders actual picture — the texture
  bridge works, which was the make-or-break risk.
- The `.deb` builds, declares `libmpv2 | libmpv1`, validates and installs.

Not proven, and not to be described as proven:

- **Hardware decode.** CI has no GPU and runs `LIBGL_ALWAYS_SOFTWARE=1`.
- **Wayland.** The smoke test is Xvfb, so X11 only.
- **No per-frame CPU copy**, and 4K60 without dropped frames.
- **The AppImage.** Built only by `release.yml`; it has never run.

## Playback core

| | |
|---|---|
| ~ | Open local files and `http(s)` URLs. Directories not yet enqueued |
| ~ | Play, pause, seek, volume. Stop/previous/next not wired to the interface |
| ✓ | `PlaybackController` interface, exact `absolute+exact` seek, frame stepping |
| ✓ | Speed 0.25×–4× with pitch correction, volume to 150 % |
| · | A–B loop, whole-file loop |
| · | Resume position, recent files persistence |
| ~ | Chapters read from the engine; no interface yet |
| ✓ | Screenshot with and without subtitles (engine side) |
| ✓ | Hardware decode on by default with a software escape hatch |
| ~ | Track selection and subtitle/audio delay implemented; no menus yet |

## Interface

| | |
|---|---|
| ✓ | Empty state with the open action, drop hint and recent list |
| ✓ | Video surface via the texture bridge, letterboxed in a themed fill |
| ~ | Transport bar — docked and provisional; the overlay version needs Slate's `scrim` roles |
| ~ | Status bar — resolution, codec, frame rate, decoder |
| · | Track bar with chapters, buffered range, hover thumbnails, review pips |
| · | Side panel, fullscreen, cursor auto-hide |

## Desktop integration

| | |
|---|---|
| ✓ | XDG base directories, never `~/.kino` |
| ✓ | Desktop entry with the full MIME set, `%U`, translated name and comment |
| ✓ | AppStream metainfo with `<mediatype>` entries |
| ✓ | GTK application id matches the desktop file, so shells match the window |
| ✓ | Drag-and-drop onto the window |
| ✓ | Files and URLs as argv |
| · | **MPRIS2 over D-Bus** |
| · | **Idle inhibit** — Wayland `idle-inhibit-unstable-v1` and X11 ScreenSaver |
| · | Same-file lock under `$XDG_RUNTIME_DIR` |
| · | System theme following, recent files in the XDG recent manager |

## Playlist, preferences

| | |
|---|---|
| · | Everything in §3 and §4 |

## Review mode

The reason the module exists. The pure-Dart half is done and exhaustively
tested; none of it is wired to an interface yet.

| | |
|---|---|
| ✓ | Exact rational frame rates, integer position ↔ frame conversion |
| ✓ | SMPTE timecode, drop-frame at 29.97 and 59.94, decimal, parsing |
| ✓ | In/out marks with inclusive ranges and loop targets |
| ✓ | Annotations: UUIDs, actor with nullable `userId`, UTC stamps, categories |
| ✓ | Vector drawings in normalised frame coordinates |
| ✓ | Sidecar format, JSON round trip, schema versioning |
| ✓ | Import and merge of a second reviewer's pass, including rate rebasing |
| ✓ | CSV and Markdown export |
| · | PDF export with a composited still |
| · | The entire review interface — timecode field, marks on the track bar, the annotations panel, drawing tools |
| · | Compare mode (stretch) |
