# Licensing

Kino is **AGPL-3.0-or-later**. That is the same licence as the rest of the
suite, but here it sits on top of a dependency graph the other modules do not
have, and the graph is the part worth reading.

## The short version

| Component | Licence | How Kino uses it | Verdict |
|---|---|---|---|
| Kino | AGPL-3.0-or-later | — | — |
| `slate_ui` | MIT | Dart dependency | Compatible with anything |
| `media_kit`, `media_kit_video`, `media_kit_libs_linux` | MIT | Dart dependency | Compatible with anything |
| libmpv | **GPL-2.0-or-later** | Loaded at runtime with `dlopen` | Compatible — **because of the "or later"** |
| FFmpeg | LGPL-2.1-or-later, or GPL-2.0-or-later when built `--enable-gpl` | Reached only through libmpv | Compatible either way |
| libass, libplacebo, dav1d, … | ISC / LGPL / BSD | Reached only through libmpv | Compatible |
| Flutter engine, Dart | BSD-3-Clause | Linked into the binary | Compatible |

## Why the "or later" on mpv is the whole ballgame

AGPLv3 is compatible with GPLv3 — [GPLv3 §13][gpl13] grants the permission
explicitly, in both directions. It is **not** compatible with GPLv2-only:
GPLv2 has no such clause, and its §6 forbids adding the further restriction
that AGPL's §13 amounts to.

mpv is *GPL-2.0-or-later*. The "or later" permits any recipient to take it under
GPLv3, and at GPLv3 the combination with an AGPLv3 application is lawful. Had
mpv been GPLv2-only, Kino could not have shipped as AGPL at all and this file
would be recommending GPLv3 for this module instead.

**This is therefore a fact to verify per build, not once.** `mpv` can also be
compiled `--enable-lgpl`, which yields LGPL-2.1+ at the cost of some features;
distributions do not do this, but a vendor might.
`tools/audit_licenses.sh` runs in CI and on every release for exactly this
reason.

[gpl13]: https://www.gnu.org/licenses/gpl-3.0.html#section13

## FFmpeg is licensed twice

FFmpeg is LGPL-2.1-or-later by default and **GPL-2.0-or-later** when built with
`--enable-gpl`, which pulls in x264, x265 and several filters. Distributions
differ. Either way the result stays compatible here, because the combined work
already takes GPLv3 terms via mpv — but the *obligation* differs: a GPL FFmpeg
tightens what has to be offered as source.

Debian and Ubuntu build FFmpeg with `--enable-gpl`. Assume GPL.

## What each artefact distributes

This is where the two packaging formats genuinely diverge, and the reason
`docs/PACKAGING.md` treats them separately.

### The `.deb` — distributes no third-party binary

The Debian package contains Kino, the Flutter engine, and nothing else native.
It **depends on** the distribution's libmpv:

```
Depends: … , libmpv2 | libmpv1
```

Because Kino distributes no GPL binary, the source-offer obligation for libmpv
and FFmpeg stays with the distribution, which already meets it through its own
archive. This is the recommended artefact and the legally boring one.

Note that this dependency is **declared by hand** in
`packaging/build_deb.sh`, not discovered by `dpkg-shlibdeps`. `media_kit`
`dlopen`s libmpv rather than linking it, so no SONAME appears in the ELF. The
alternative `libmpv2 | libmpv1` is what lets one package install on Ubuntu
22.04 (libmpv1) and 24.04+ (libmpv2) alike.

### The AppImage — distributes GPL binaries, and carries the obligation

The AppImage bundles libmpv, FFmpeg and the rest of the media stack, because a
self-contained image cannot assume the host has them. Distributing those
binaries triggers GPLv3 §6: the corresponding source must be offered.

`packaging/build_appimage.sh` therefore writes, inside every image:

- `usr/share/licenses/LICENSE.Kino.AGPL-3.0.txt` — Kino's own licence.
- `usr/share/licenses/copyright.<package>.txt` — the verbatim copyright file of
  every distribution package a bundled library came from.
- `usr/share/licenses/BUNDLED.md` — a table of every bundled `.so`, the package
  and **exact version** it came from, its licence, and a written offer valid for
  three years.

The offer points at the distribution archive the binaries were taken from, and
at `rbuache@gmail.com` as a fallback. Both are permitted: the binaries are
unmodified, so their corresponding source is exactly what that archive holds.

**Do not add a library to `BUNDLE_PATTERN` in `build_appimage.sh` without
checking that the manifest picks up its copyright file.** A bundled binary with
no licence in the image is the one real licensing failure available here.

## The network clause is inert, and that is fine

AGPL's §13 obliges you to offer source to users who interact with the program
*over a network*. Kino has no network service — no server, no sockets, no
accounts. The clause therefore never fires.

It costs nothing and keeps the suite on one licence, which is the whole reason
to use it. If the graph ever becomes awkward — an unavoidable GPLv2-only
dependency, say — dropping this module alone to GPLv3 is defensible; record why
here and in `DECISIONS.md` if it happens.

## Open questions

These need answering on a Linux machine before v1, and are tracked in
`DECISIONS.md`:

- **Confirm mpv's licence in each target distribution's build.** Expected
  GPL-2.0-or-later everywhere; `tools/audit_licenses.sh` asserts it, but the
  assertion has not yet run against a real bundle.
- **Confirm the AppImage manifest resolves every bundled `.so` to a package.**
  The lookup in `build_appimage.sh` guesses the multiarch path; a library found
  somewhere else will be listed as `unknown`, which is not good enough to ship.
