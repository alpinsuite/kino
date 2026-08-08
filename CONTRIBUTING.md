# Contributing

## Before you start

Read [docs/DECISIONS.md](docs/DECISIONS.md). Most of what looks like an obvious
improvement here has a reason behind it, and the reasons are written down.

Read §5 of the specification, mirrored in the README's *What it will not do*.
A video player attracts feature requests endlessly, and the scope discipline is
the feature.

## The checks

```bash
dart format --set-exit-if-changed .
flutter analyze --fatal-infos
bash tools/check_hardcoded_strings.sh
bash tools/check_layer_purity.sh
flutter test
(cd packages/kino_review && dart test)
(cd packages/kino_core   && flutter test)
(cd packages/kino_media  && flutter test)
```

These are exactly what the CI analyze job runs, so a green local run means that
job is green. Packaging is not: it builds in an `ubuntu:22.04` container, and
24.04 tooling is more permissive. See [docs/PACKAGING.md](docs/PACKAGING.md).

## What a good change looks like

- **New behaviour in `packages/` has tests.** `kino_review` is headless and pure
  — there is no excuse there at all.
- **Every user-visible string** goes in `lib/l10n/app_en.arb` *and* in
  `app_de.arb`, `app_fr.arb`, `app_it.arb`, in the same change. Run
  `flutter gen-l10n` and commit the generated files.
- **No colour, size or font literal** outside the Slate theme wiring.
- **Missing a widget, an icon or a palette role?** It goes to
  [alpinsuite/ui-kit](https://github.com/alpinsuite/ui-kit) as a PR, gets a tag,
  and the pin here is bumped. That is more ceremony than editing a widget in
  place, and it is the point: the interface has a version number.
- **User-visible changes get a `CHANGELOG.md` entry** under `## [Unreleased]`.
- **Comments explain why, never what.**
- Do not bump the version. Releases do that.

## Reporting a bug

Playback bugs are much easier to act on with:

- the output of `kino --version` and of `mpv --version`;
- whether the session is X11 or Wayland (`echo $XDG_SESSION_TYPE`);
- what the status bar says about the decoder;
- whether it also happens in `mpv` itself — if it does, it is an mpv bug and
  they will want it, not us.

## Licence

Contributions are accepted under [AGPL-3.0-or-later](LICENSE), the licence of
the project. If you add or change a native dependency, say so explicitly: the
licence graph here is genuinely load-bearing and
[docs/LICENSING.md](docs/LICENSING.md) has to keep up.
