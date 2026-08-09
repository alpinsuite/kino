# TODO

The specification's build order, with what is actually done. Written against the
code rather than from memory: the "no caller" notes below come from grepping
`lib/` for each method.

`✓` done · `~` partial · `·` not started

**Where we are.** The foundations are real and tested — CI is green end to end,
the engine boundary works on two platforms, and `kino_review` is complete.
Keyboard control (§8) and the desktop integration (§9) are now built, which
means the engine's capabilities are finally reachable: stepping, speed, delays,
screenshots and the seek steps all had implementations and no callers until now.

What remains is mostly *interface*. There is still no playlist, no preferences,
no track menus, no track bar, and — the important one — **no review interface at
all**, despite `kino_review` being the reason the module exists and being
finished underneath. Two things are written but unverified: MPRIS and idle
inhibit have never run against a real session bus, and build order step 2 is
still open.

---

## 1. Scaffold, licensing, CI, packaging, Slate — ✓

Done. `docs/LICENSING.md` settles the AGPL/GPL graph and
`tools/audit_licenses.sh` re-checks it per build. CI runs format, analyze, l10n
staleness, both purity gates, 24 app/package tests, the licence audit, a
headless playback smoke test, and the `.deb` build + install.

## 2. Prove `media_kit` end to end — ~ **and this is the open gate**

The specification says to resolve this *before any interface work*. It is not
resolved, and everything below inherits that risk.

| | |
|---|---|
| ✓ | A file plays in a Flutter texture (CI smoke test, and the Windows build) |
| ✓ | Works in the `.deb` — built, validated and installed in CI |
| · | **Works in the AppImage** — only `release.yml` builds it, so it has *never run* |
| · | **Hardware decode confirmed** — CI has no GPU and forces `LIBGL_ALWAYS_SOFTWARE` |
| · | **Wayland** — the smoke test is Xvfb, so X11 only |
| · | No per-frame CPU copy; 4K60 without dropped frames |

## 3. `PlaybackController` in `kino_media` — ✓

Interface, libmpv implementation, `UnavailablePlaybackController`, and the
`PlaybackSurface` boundary. `tools/check_layer_purity.sh` keeps `media_kit`
inside the package.

## 4. Minimal window — ✓

Video surface, play/pause, seek, volume, empty state, drag-and-drop, status bar.

## 5. Overlay transport bar — · **blocked upstream**

Needs `scrim`/`overlay` roles in `SlatePalette`. The icon half is done
(`slate_ui` v0.6.0). Still needed in the kit: the scrim roles, `SlateOverlayBar`,
and glyphs for stop, previous, next, frame-step, subtitles, audio track,
fullscreen, mark-in, mark-out.

## 6. Track bar — ·

Chapter ticks, buffered range, review pips, hover-preview thumbnails cached in
`$XDG_CACHE_HOME`. Wants `SlateTrackBar` in the kit. Chapters are already read
off the engine into `MediaInfo` and displayed nowhere.

## 7. Track selection and delays — ~ engine only

`selectTrack`, `addSubtitleFile`, `setSubtitleDelay`, `setAudioDelay` all work
and **none has a caller**. Needs menus, an OSD readout for the delays, subtitle
styling and an encoding override.

## 8. Keyboard — ✓ core done

`KinoCommand` + a default binding table + `AppActions`, wired with
`CallbackShortcuts` under an autofocused `Focus`. mpv-compatible where sensible;
the two departures are recorded in DECISIONS 15. `Esc` leaves fullscreen and
never quits, and no bare key is bound to quit — both asserted by tests.

Bound and reachable now: play/pause, the three seek steps, frame stepping,
volume, mute, speed, fullscreen, screenshot, subtitle and audio delay, theme.

| | |
|---|---|
| · | Remapping and persistence (needs §12) |
| · | An mpv-compatible preset |
| · | Chapter jumps, A–B loop, playlist next/previous — no command yet |
| · | An OSD readout, so the delay and speed keys give feedback |

## 9. MPRIS2 and idle inhibit — ~ written, unverified on a real bus

Both implemented in pure Dart over `package:dbus`, both best-effort: a session
without a bus costs the shell controls, never playback.

| | |
|---|---|
| ✓ | MPRIS2 root and Player interfaces: properties, methods, `PropertiesChanged` |
| ✓ | Idle inhibit via `org.freedesktop.ScreenSaver`, falling back to PowerManagement |
| ✓ | The mapping and the inhibit policy are unit-tested |
| · | **Never run against a real session bus.** No D-Bus on the development machine and no desktop in CI |
| · | Media keys, and the GNOME/KDE shell entry, unverified |
| · | `CanGoNext`/`CanGoPrevious` are false until there is a playlist |

The Wayland `idle-inhibit-unstable-v1` protocol is *not* used; D-Bus is, and
DECISIONS 9 explains why and what it costs.

## 10. Playlist panel — ·

Nothing exists. `parseArguments` builds a playlist and `AppShell` opens only the
first entry; a dropped file replaces rather than enqueues. Needs the side panel,
natural sort, shuffle/repeat, auto-advance, `.m3u`.

## 11. Resume, recent files, session restore — · **not wired**

`MediaKey` (content-addressed, tested) and `XdgPaths` (tested) both exist and
**nothing in `lib/` uses either**. The recent list is an in-memory `List<Uri>`
that dies with the process.

## 12. Preferences — ·

`XdgPaths.settingsFile` is computed and never read or written. No settings model,
no dialog.

## 13. XDG integration, MIME, same-file lock — ~

| | |
|---|---|
| ✓ | Desktop entry with the full MIME set, `%U`, translated name/comment |
| ✓ | AppStream metainfo with `<mediatype>` |
| ✓ | GTK application id matches the desktop file |
| · | Same-file lock under `$XDG_RUNTIME_DIR` |
| · | XDG recent manager registration |

## 13a. Dark / light theme selection — ~ **half built, and invisible**

Called out separately because it is a user-facing feature hiding inside a
plumbing section. §0.5: *"follow light/dark onto `SlateThemeData.light()` /
`.dark()`, manual override in preferences. Default to dark; it is a video
player."*

| | |
|---|---|
| ✓ | `ThemeController` with `system` / `light` / `dark`, resolving against the platform brightness |
| ✓ | Repaints when the desktop theme changes, via `MediaQuery.platformBrightnessOf` |
| · | **Nothing ever sets the mode.** It is fixed at `system` for the life of the process |
| · | No way for a user to override it — no menu item, no shortcut, no preferences |
| · | The choice is not persisted (needs §12) |

The controller is the whole hard part and it is done. What is missing is a
control that calls `theme.mode = …` and somewhere to remember the answer.

## 14. `.deb`, AppImage, APT repo — ~

`.deb` builds and installs in CI. The AppImage and `publish_apt.sh` have never
executed — both only run on a tag.

## 15. Review mode — ~ **the whole point, and entirely headless**

`kino_review` is complete and exhaustively tested: exact rational frame rates,
SMPTE with drop-frame, marks, annotations, categories, vector drawings, the
sidecar with merge and rate rebasing, CSV and Markdown export.

**None of it is reachable from the interface.** Still needed: the review toggle,
timecode display and go-to-timecode field, frame stepping bound to keys, marks
on the track bar, the annotations panel, drawing tools, PDF export with a
composited still, sidecar load/save, and import.

---

## Acceptance criteria (§ "Acceptance criteria for v1")

| | |
|---|---|
| ~ | Plays H.264/H.265/VP9/AV1 in MP4/MKV/WebM — libmpv does; only H.264 has been run |
| · | Hardware decode on Intel and AMD with visible indicator — indicator built, never seen non-`Software` |
| · | 4K60, no dropped frames, no per-frame CPU copy |
| · | Seek within one frame — `seekToFrame` is exact by construction and untested against media |
| ~ | Frame-step exact and repeatable — bound to `.` and `,`, never checked against media |
| · | Embedded and external subtitles, styled ASS |
| ~ | Subtitle/audio delay — bound to keys; no OSD readout |
| · | Resume after a move or rename |
| · | Identical on X11 and Wayland |
| ~ | Every action reachable by keyboard — the implemented ones are; remapping is not built |
| ~ | Media keys and shell integration — written, never run on a bus |
| ~ | Screen does not blank during playback — written, never run on a bus |
| ✓ | All four locales render without overflow (tested at the 600×380 minimum) |
| ✓ | No colour or size literal outside the Slate theme wiring |
| ✓ | Licences enumerated, compatible and documented |

---

## Recommended order

1. **Run it on a Linux desktop.** Two features now depend on it: MPRIS and idle
   inhibit are written and cannot be verified anywhere else. Media keys either
   work or they do not, and nothing short of a real session bus will say which.
   Fold in the step-2 gate at the same time — build the AppImage in CI rather
   than only on a tag, and get one run against a GPU and a Wayland session.
2. **Review mode interface.** The reason the module exists, and the largest
   remaining gap between what is built and what is usable. The hard part —
   frame-exact arithmetic, marks, annotations, the sidecar, export — is done and
   exhaustively tested; what is missing is entirely interface.
3. **Resume and recent files.** `MediaKey` and `XdgPaths` are built and tested
   and used by nothing; this is a store and some wiring.
4. **Preferences.** Unlocks three things that are otherwise half-features:
   persisted theme, remappable keys, and the resume threshold.
5. **An OSD.** The delay and speed keys currently change something with no
   feedback at all, which is close to useless in the dark.
6. Track bar, side panel, track menus and the playlist, alongside the `ui-kit`
   work each needs.
