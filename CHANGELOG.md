# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Project scaffold: a pub workspace with the application and three packages —
  `kino_core`, `kino_media` and `kino_review`.
- `kino_review`, complete and exhaustively tested: exact rational frame rates,
  integer position ↔ frame conversion, SMPTE timecode with drop-frame support at
  29.97 and 59.94, in/out marks, annotations with categories and vector
  drawings, the `<video>.kino.json` sidecar format, merge of a second reviewer's
  pass, and CSV and Markdown export.
- `kino_core`: playback state and media description, content-addressed
  `MediaKey` so resume positions and sidecars survive a rename, and XDG base
  directory resolution.
- `kino_media`: the `PlaybackController` boundary and its libmpv implementation
  over `media_kit` — exact seeking, frame stepping in both directions, track
  selection, subtitle and audio delay, screenshots, volume to 150 %, and a
  hardware-decoder readout.
- A minimal window: empty state with recent files, the video surface, and a
  docked transport and status bar.
- Localisation in English, German, French and Italian.
- Packaging: `.deb`, AppImage with bundled licences and a written source offer,
  a signed APT repository, AppStream metainfo, desktop entry with the full MIME
  set, and a man page.
- CI: formatting, analysis, localisation staleness, hardcoded-string and
  layer-purity gates, tests, a licence audit, and a headless playback smoke test.
- `docs/LICENSING.md` settling the AGPL/GPL graph, and `docs/DECISIONS.md`.

[Unreleased]: https://github.com/AlpinSuite/kino/commits/main
