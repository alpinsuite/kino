# Releasing

`pubspec.yaml` is the single source of truth for the version. Everything else is
propagated from it.

```bash
tools/set_version.sh              # print the current version
tools/set_version.sh 0.2.0        # set it everywhere
```

That writes `pubspec.yaml` (bumping the monotonic build number),
`lib/core/app_version.dart`, and adds a release entry to
`packaging/deb/ch.alpinsuite.Kino.metainfo.xml`. The Debian control file reads
the version from `pubspec.yaml` at build time and needs no editing.

## Steps

1. Confirm CI is green on `main`.
2. `tools/set_version.sh <version>`
3. Move the `## [Unreleased]` notes in `CHANGELOG.md` under
   `## [<version>] - <date>`.
4. `git commit -am "Release <version>"`
5. `git tag -s v<version> -m "Release <version>"` — signed, per the suite
   convention.
6. `git push --follow-tags`

Pushing the tag runs `.github/workflows/release.yml`, which:

- checks the tag matches the pubspec version and fails loudly if not;
- runs the tests and the layer-purity check;
- builds the release bundle in the `ubuntu:22.04` container;
- **runs the licence audit** — a release is the artefact the obligation attaches
  to, so this is a gate here and not only on CI;
- builds the `.deb` and the portable tarball, then the AppImage
  (`continue-on-error`: a broken `appimagetool` download must not hold back the
  primary artefact);
- publishes the GitHub release with the changelog section as its notes;
- regenerates and pushes the signed APT repository to `gh-pages`.

## Secrets

| Secret | Used for |
|---|---|
| `APT_GPG_PRIVATE_KEY` | Signing `InRelease` and `Release.gpg` |
| `APT_GPG_PASSPHRASE` | That key's passphrase, if it has one |

Without them the repository is generated unsigned, and apt will refuse it.

## Versioning

Semantic versioning. A change to the Slate pin that alters the interface is a
minor bump even though the analyzer will not say so — a consumer's interface is
built out of those colours and sizes.

Do not bump the version in an ordinary change. Releases do that.
