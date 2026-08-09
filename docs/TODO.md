# TODO

The specification's build order, with what is actually done. Written against the
code rather than from memory: the "no caller" notes below come from grepping
`lib/` for each method.

`✓` done · `~` partial · `·` not started

**Where we are.** The foundations are real and tested — CI is green end to end,
the engine boundary works on two platforms, and `kino_review` is complete. The
*interface* is a shell. Eight `PlaybackController` methods have no caller
anywhere in `lib/`: the engine can step frames, change speed, select tracks,
shift subtitle and audio delay, screenshot and seek to a frame, and nothing in
the application asks it to. There are **no keyboard bindings at all**, which for
a video player is the single largest gap.

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

## 8. Keyboard — · **nothing at all**

No `Shortcuts`, no `Actions`, no key handling anywhere. For an application used
in the dark this is the largest single gap. Defaults should match mpv;
`Esc` exits fullscreen and never quits; `Space` toggles play. Remapping and an
mpv-compatible preset come later, but the bindings themselves are overdue.

Also unreachable without them: frame stepping (`.` and `,`), speed, screenshot,
A–B loop, chapter jumps, the seek steps (±5 s, ±1 s with Shift, ±60 s with Ctrl).

## 9. MPRIS2 and idle inhibit — ·

§0.5 calls these non-negotiable, and DECISIONS 9 already sets
`wakelock: false` so there is nothing to un-wire.

- MPRIS2 over D-Bus: `org.mpris.MediaPlayer2` and `.Player`. Without it there
  are no media keys and no entry in the GNOME/KDE shell controls.
- Idle inhibit: Wayland `idle-inhibit-unstable-v1`, X11 `org.freedesktop.ScreenSaver`.
  Release on pause. "The screen does not blank during playback, and does blank
  when paused" is an acceptance criterion.

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
| · | System theme following (the controller exists; nothing changes its mode) |

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
| · | Frame-step exact and repeatable — no caller |
| · | Embedded and external subtitles, styled ASS |
| · | Subtitle/audio delay with OSD readout |
| · | Media keys and shell integration (MPRIS) |
| · | Screen does not blank during playback |
| · | Resume after a move or rename |
| · | Identical on X11 and Wayland |
| · | Every action reachable by keyboard |
| ✓ | All four locales render without overflow (tested at the 600×380 minimum) |
| ✓ | No colour or size literal outside the Slate theme wiring |
| ✓ | Licences enumerated, compatible and documented |

---

## Recommended order

1. **Close the step-2 gate.** Build the AppImage in CI, not only on a tag, and
   get one run against a GPU and a Wayland session. Everything below assumes
   the engine works in the shipped artefacts, and that is still assumed.
2. **Keyboard bindings.** Cheapest large win: eight engine capabilities are
   already implemented and unreachable, so this is mostly wiring, and it makes
   the player usable.
3. **MPRIS2 and idle inhibit.** The two things Linux users notice missing within
   five minutes, and the two things Flutter applications almost always skip.
4. **Resume and recent files.** `MediaKey` and `XdgPaths` are built and tested;
   this is the store and the wiring.
5. **Review mode interface.** The reason the module exists. The hard part —
   frame-exact arithmetic — is done and tested; what remains is interface.
6. Track bar, side panel and preferences, alongside the `ui-kit` work they need.
