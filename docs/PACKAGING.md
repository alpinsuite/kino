# Packaging

Two artefacts, and they are not equivalent — see
[LICENSING.md](LICENSING.md) for why the difference matters legally.

```bash
flutter build linux --release          # → build/linux/x64/release/bundle/kino
bash packaging/build_deb.sh            # → build/dist/kino_<version>_amd64.deb
bash packaging/build_appimage.sh       # → build/dist/Kino-<version>-x86_64.AppImage
bash packaging/publish_apt.sh /tmp/repo build/dist/*.deb
```

## The glibc baseline

Release binaries are built in an `ubuntu:22.04` container so they link against
glibc 2.35 and run on Ubuntu 22.04+, Debian 12+ and anything newer. Building on
a 24.04 runner produces a binary that hard-requires glibc 2.39 and excludes
every one of those.

Green packaging locally does **not** imply green packaging in CI: 24.04 tooling
is more permissive than 22.04's. The container is the arbiter.

The container does not, however, pin libmpv. `media_kit` `dlopen`s it, so a
package built here finds `libmpv.so.1` on 22.04 and `libmpv.so.2` on 24.04.

## The `.deb`

- Depends on the distribution's libmpv: `libmpv2 | libmpv1`. Declared by hand,
  because `dpkg-shlibdeps` cannot see a `dlopen`. CI fails the build if the
  declaration goes missing.
- Recommends `mesa-va-drivers`, `libva2`, `libva-drm2` — hardware decoding needs
  them, but a machine on the NVIDIA proprietary stack does not.
- Everything else is computed by `dpkg-shlibdeps` from the ELF binaries, so it
  stays correct as the Flutter engine's own dependencies change.
- The bundle lives under `/usr/lib/kino`; only a launcher goes on `PATH`,
  because the engine resolves its data relative to the executable and cannot be
  reached through a symlink.

## The AppImage

Bundles libmpv, FFmpeg, libass and the rest of the media stack. Does **not**
bundle glibc, GTK, GL, X11/Wayland or the graphics drivers — hardware decoding
needs the host's own, and bundling them is how an AppImage stops working on the
machines it was meant for.

The selection is an allowlist (`BUNDLE_PATTERN` in `build_appimage.sh`), not an
excludelist. An excludelist bundles whatever it failed to think of, and the
failure mode only shows up on someone else's machine.

Every bundled library's licence, its exact source package and version, and a
written source offer are generated into `usr/share/licenses/` inside the image.
Adding a library to the pattern without checking the manifest picks up its
copyright file is the one real licensing failure available here.

## Icons

Only the scalable SVG is committed. `packaging/render_icons.sh` renders the
hicolor PNG sizes at build time with `rsvg-convert` (or `inkscape`), so the mark
cannot drift between sizes and a change to it is a diff a human can read. Without
either tool the scalable icon alone is installed, which GNOME and KDE both
render; only the AppImage's root icon really wants a raster.

## The APT repository

`packaging/publish_apt.sh` regenerates the signed repository published to GitHub
Pages at <https://alpinsuite.github.io/kino>. Existing pool entries are kept, so
older versions stay installable and `apt upgrade` has something to compare
against. Signing needs `APT_GPG_PRIVATE_KEY` and `APT_GPG_PASSPHRASE` in the
environment; without them the layout is still generated, which is enough to test
locally, but apt will refuse an unsigned repository.

## Validation

`desktop-file-validate` on 24.04 (0.27) accepts spec `Version=1.5`; the 22.04
one CI uses (0.26) rejects it. The desktop entry declares 1.1 for that reason.

Container base images ship `/etc/dpkg/dpkg.cfg.d/excludes`, which drops
`/usr/share/man` and most of `/usr/share/doc` on install. Check documentation
with `dpkg-deb --contents`, not on the filesystem.
