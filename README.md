# Kino

A fast, native video player for the Linux desktop. It opens a file, plays it
correctly, and stays out of the way.

Playback is [libmpv](https://mpv.io), so every container and codec FFmpeg
understands works, hardware decoding is on by default with a clean fall back to
software, and subtitles render through libass. The interface is
[Slate](https://github.com/alpinsuite/ui-kit) — flat surfaces, hairline rules,
one restrained accent — the same visual language as the rest of AlpinSuite.

**Linux only.** That is a feature: it buys GTK-native behaviour, proper XDG
integration, MPRIS and media keys, VA-API hardware decode, and `.deb` and
AppImage distribution, with no compromises made for another platform.

## Why this exists

Linux video playback is a solved problem. mpv is excellent and has no interface;
Celluloid and Haruna are good frontends to it; VLC plays everything and looks
like 2009. Kino is not filling a functional hole, and it would be dishonest to
pretend otherwise.

It exists for three narrower reasons:

1. **Suite consistency** — it looks and behaves like PDF Ninja and FluidPlan.
2. **A dense, quiet interface** — Slate, not chrome-heavy Qt.
3. **Review mode**, which is the real one.

### Review mode

The part no existing Linux player does well. For the people who need to say
*"at 04:12 the weld is wrong"* and hand that to someone else — site inspection
footage, engineering walkthroughs, training material, quality sign-off.

- SMPTE timecode (`HH:MM:SS:FF`), with drop-frame at 29.97 and 59.94, or decimal.
- Frame-exact stepping and seeking. Frames, not keyframes.
- In and out marks, with a loop inside the range.
- Notes attached to a **frame**, not to an approximate second, with an author
  and a category.
- Vector drawings — arrow, rectangle, ellipse, freehand — stored over the frame,
  never baked into it.
- Export to CSV, Markdown or PDF. Import a colleague's pass and merge it.
- Sidecars live beside the media as `<video>.kino.json`. The video file is never
  modified.

## Status

Early. The scaffold, the packaging pipeline, the engine boundary and the whole
pure-Dart review core are in place and tested; most of the interface is not.
[docs/FEATURES.md](docs/FEATURES.md) tracks it honestly, line by line.

## Install

Once the first release is out:

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://alpinsuite.github.io/kino/kino-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/kino.gpg > /dev/null
sudo curl -fsSL -o /etc/apt/sources.list.d/kino.sources \
  https://alpinsuite.github.io/kino/kino.sources
sudo apt update && sudo apt install kino
```

An AppImage is published alongside for distributions that are not
Debian-derived.

## Building

```bash
flutter pub get
flutter test
flutter build linux --release
bash packaging/build_deb.sh
```

Flutter **3.44.8**, and `libmpv-dev` plus the usual GTK desktop toolchain. See
[CLAUDE.md](CLAUDE.md) for the full command list and
[docs/PACKAGING.md](docs/PACKAGING.md) for why release builds happen in an
`ubuntu:22.04` container.

## What it will not do

No transcoding, no editing or trimming, no media library, no casting, no
streaming-service integration, no plugin system, and no video filters beyond
deinterlacing. HandBrake, Kdenlive and Jellyfin all exist and are better at
those than a player should try to be.

No telemetry, no accounts, no sockets.

## Licence

[AGPL-3.0-or-later](LICENSE). The licence graph under this one is not trivial —
libmpv is GPL-2.0-*or-later*, and the "or later" is what makes the combination
lawful. [docs/LICENSING.md](docs/LICENSING.md) works through it, and
`tools/audit_licenses.sh` re-checks it on every build.
