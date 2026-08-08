#!/usr/bin/env bash
#
# Builds (or refreshes) the signed APT repository served from GitHub Pages.
#
#   packaging/publish_apt.sh <output-dir> <deb> [<deb>...]
#
# The output directory is the gh-pages worktree. Existing pool entries are kept,
# so publishing a new version leaves older ones installable and `apt upgrade`
# has something to compare against.
#
# Signing needs a private key in the environment:
#   APT_GPG_PRIVATE_KEY   ASCII-armoured private key
#   APT_GPG_PASSPHRASE    its passphrase (optional if the key has none)
#
# Without a key the repository is still generated but left unsigned, which is
# enough to test the layout locally; apt itself will refuse an unsigned repo.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

OUTPUT="${1:?usage: publish_apt.sh <output-dir> <deb>...}"
shift
if [[ $# -eq 0 ]]; then
  echo "no .deb files given" >&2
  exit 2
fi

ORIGIN="Kino"
LABEL="Kino"
SUITE="stable"
COMPONENT="main"
ARCHITECTURES="amd64"
PAGES_URL="${PAGES_URL:-https://alpinsuite.github.io/kino}"
KEYRING_NAME="kino-archive-keyring.gpg"

mkdir -p "$OUTPUT/pool/$COMPONENT/k/kino"
# The landing page advertises the newest package, so it needs to know which of
# these that is. Recorded here rather than later because the script changes
# directory below and these paths are the caller's, not ours.
for deb in "$@"; do
  cp -f "$deb" "$OUTPUT/pool/$COMPONENT/k/kino/"
  DEB_FILE="$(basename "$deb")"
  DEB_SIZE="$(du -h "$deb" | cut -f1)"
done

for arch in $ARCHITECTURES; do
  mkdir -p "$OUTPUT/dists/$SUITE/$COMPONENT/binary-$arch"
done

cd "$OUTPUT"

# apt-ftparchive walks pool/ and writes the package index. Paths in the index
# must be relative to the repository root, hence running from here.
for arch in $ARCHITECTURES; do
  apt-ftparchive --arch "$arch" packages pool \
    > "dists/$SUITE/$COMPONENT/binary-$arch/Packages"
  gzip -9nkf "dists/$SUITE/$COMPONENT/binary-$arch/Packages"
done

cat > "$OUTPUT/apt-ftparchive-release.conf" <<CONF
APT::FTPArchive::Release::Origin "$ORIGIN";
APT::FTPArchive::Release::Label "$LABEL";
APT::FTPArchive::Release::Suite "$SUITE";
APT::FTPArchive::Release::Codename "$SUITE";
APT::FTPArchive::Release::Architectures "$ARCHITECTURES";
APT::FTPArchive::Release::Components "$COMPONENT";
APT::FTPArchive::Release::Description "Kino video player";
CONF

# Written outside the tree first: the shell would otherwise create an empty
# Release before apt-ftparchive scans the directory, and it would hash that
# placeholder into its own index.
rm -f "dists/$SUITE/Release" "dists/$SUITE/InRelease" "dists/$SUITE/Release.gpg"
RELEASE_TMP="$(mktemp)"
apt-ftparchive -c "$OUTPUT/apt-ftparchive-release.conf" \
  release "dists/$SUITE" > "$RELEASE_TMP"
mv "$RELEASE_TMP" "dists/$SUITE/Release"
rm -f "$OUTPUT/apt-ftparchive-release.conf"

if [[ -n "${APT_GPG_PRIVATE_KEY:-}" ]]; then
  GNUPGHOME="$(mktemp -d)"
  export GNUPGHOME
  chmod 700 "$GNUPGHOME"
  printf '%s' "$APT_GPG_PRIVATE_KEY" | gpg --batch --quiet --import

  KEY_ID="$(gpg --list-secret-keys --with-colons | awk -F: '/^sec:/ {print $5; exit}')"
  if [[ -z "$KEY_ID" ]]; then
    echo "the supplied APT_GPG_PRIVATE_KEY contains no secret key" >&2
    exit 1
  fi

  GPG_ARGS=(--batch --yes --quiet --local-user "$KEY_ID")
  if [[ -n "${APT_GPG_PASSPHRASE:-}" ]]; then
    GPG_ARGS+=(--pinentry-mode loopback --passphrase "$APT_GPG_PASSPHRASE")
  fi

  # Both signatures are produced: InRelease for modern apt, Release.gpg for
  # older clients that still look for a detached signature.
  gpg "${GPG_ARGS[@]}" --clearsign \
    --output "dists/$SUITE/InRelease" "dists/$SUITE/Release"
  gpg "${GPG_ARGS[@]}" --armor --detach-sign \
    --output "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"

  # The public key is published in binary (dearmoured) form, which is what
  # signed-by= expects in /etc/apt/keyrings.
  gpg --batch --yes --export "$KEY_ID" > "$KEYRING_NAME"

  rm -rf "$GNUPGHOME"
  unset GNUPGHOME
  echo "signed with $KEY_ID"
else
  echo "warning: APT_GPG_PRIVATE_KEY is not set; repository left unsigned" >&2
fi

# A ready-made deb822 source file, so installing is two commands rather than a
# hand-written sources.list line.
cat > "$OUTPUT/kino.sources" <<SOURCES
Types: deb
URIs: $PAGES_URL
Suites: $SUITE
Components: $COMPONENT
Architectures: $ARCHITECTURES
Signed-By: /etc/apt/keyrings/kino.gpg
SOURCES

DEB_VERSION="${DEB_FILE#kino_}"
DEB_VERSION="${DEB_VERSION%_*}"
DEB_PATH="pool/$COMPONENT/k/kino/$DEB_FILE"

# The icon is carried over from the source tree rather than hotlinked to
# raw.githubusercontent: that is a second host that can rate-limit or move, and
# this page has to work for someone who arrived to install software.
cp -f "$REPO_ROOT/packaging/icons/ch.alpinsuite.Kino.svg" "$OUTPUT/kino.svg"

# No backticks and no dollar signs below except the ones meant to expand: the
# heredoc is unquoted so the URLs and the version can be interpolated.
cat > "$OUTPUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kino — a video player and review tool for Linux</title>
<meta name="description" content="A fast, native video player for Linux. Plays everything, and adds frame-exact review notes you can hand to someone else.">
<link rel="icon" href="kino.svg">
<style>
  :root {
    --bg: #ffffff; --panel: #f6f7f9; --line: #e4e7ec; --ink: #22262c;
    --dim: #667080; --accent: #a8681a; --accent-ink: #ffffff;
    --code-bg: #f4f5f7; --shadow: 0 1px 2px rgba(20,25,35,.06), 0 8px 24px rgba(20,25,35,.08);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #16181c; --panel: #1c1f24; --line: #2b3138; --ink: #d8dde4;
      --dim: #8a939f; --accent: #e0a33e; --accent-ink: #1b1206;
      --code-bg: #1a1d22; --shadow: 0 1px 2px rgba(0,0,0,.4), 0 10px 30px rgba(0,0,0,.35);
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 0 1.25rem 5rem;
    font-family: system-ui, -apple-system, "Segoe UI", Ubuntu, sans-serif;
    line-height: 1.6; color: var(--ink); background: var(--bg);
    -webkit-font-smoothing: antialiased;
  }
  .wrap { max-width: 54rem; margin: 0 auto; }
  header { text-align: center; padding: 4rem 0 2.5rem; }
  header img.logo { width: 84px; height: 84px; }
  h1 { font-size: 2.75rem; letter-spacing: -.02em; margin: 1rem 0 .4rem; }
  .tagline { font-size: 1.2rem; color: var(--dim); margin: 0 auto; max-width: 34rem; }
  .cta { margin: 2.25rem 0 .75rem; display: flex; gap: .75rem;
         justify-content: center; flex-wrap: wrap; }
  a.button {
    display: inline-flex; align-items: center; gap: .6rem;
    background: var(--accent); color: var(--accent-ink);
    text-decoration: none; font-weight: 600; font-size: 1.05rem;
    padding: .8rem 1.5rem; border-radius: 8px; border: 1px solid var(--accent);
    transition: transform .06s ease, filter .15s ease;
  }
  a.button:hover { filter: brightness(1.07); }
  a.button:active { transform: translateY(1px); }
  a.button.secondary {
    background: transparent; color: var(--ink); border-color: var(--line);
    font-weight: 500;
  }
  a.button.secondary:hover { background: var(--panel); filter: none; }
  .meta { color: var(--dim); font-size: .9rem; margin: 0; }
  h2 { font-size: 1.4rem; letter-spacing: -.01em; margin: 3.5rem 0 .5rem;
       padding-top: 2rem; border-top: 1px solid var(--line); }
  h2:first-of-type { margin-top: 3rem; }
  h3 { font-size: 1rem; margin: 1.75rem 0 .4rem; }
  p { margin: .5rem 0 1rem; }
  p.lead { color: var(--dim); }
  pre {
    background: var(--code-bg); border: 1px solid var(--line);
    padding: 1rem 1.1rem; overflow-x: auto; border-radius: 8px;
    font-size: .875rem; line-height: 1.65; margin: .5rem 0 1rem;
  }
  code { font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace; }
  ul.features { list-style: none; padding: 0; margin: 1rem 0;
                display: grid; gap: .55rem 1.5rem;
                grid-template-columns: repeat(auto-fit, minmax(15rem, 1fr)); }
  ul.features li { padding-left: 1.35rem; position: relative; color: var(--dim); }
  ul.features li strong { color: var(--ink); font-weight: 600; }
  ul.features li::before {
    content: "—"; position: absolute; left: 0; color: var(--accent);
  }
  footer { margin-top: 4rem; padding-top: 1.5rem; border-top: 1px solid var(--line);
           color: var(--dim); font-size: .9rem; display: flex;
           justify-content: space-between; gap: 1rem; flex-wrap: wrap; }
  a { color: var(--accent); }
  footer a { color: var(--dim); }
  @media (max-width: 34rem) {
    header { padding-top: 2.5rem; }
    h1 { font-size: 2.1rem; }
    a.button { width: 100%; justify-content: center; }
  }
</style>

<div class="wrap">
  <header>
    <img class="logo" src="kino.svg" alt="">
    <h1>Kino</h1>
    <p class="tagline">A fast, native video player for Linux. It opens a file,
       plays it correctly, and stays out of the way.</p>

    <div class="cta">
      <a class="button" href="$DEB_PATH" download>
        <svg width="18" height="18" viewBox="0 0 16 16" fill="none"
             stroke="currentColor" stroke-width="1.6" stroke-linecap="round"
             stroke-linejoin="round" aria-hidden="true">
          <path d="M8 2.5v7.5"/><path d="M4.5 7L8 10.5 11.5 7"/>
          <path d="M2.5 12.5v1h11v-1"/>
        </svg>
        Download for Linux
      </a>
      <a class="button secondary" href="https://github.com/AlpinSuite/kino/releases/latest">
        AppImage &amp; other downloads
      </a>
    </div>
    <p class="meta">$DEB_FILE &middot; $DEB_SIZE &middot; 64-bit Debian package</p>
  </header>

  <h2>Install with apt</h2>
  <p class="lead">Adds the signed repository, so <code>apt upgrade</code> keeps
     Kino current along with everything else on the machine.</p>
  <pre><code>sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL $PAGES_URL/$KEYRING_NAME \\
  | sudo tee /etc/apt/keyrings/kino.gpg > /dev/null
sudo curl -fsSL -o /etc/apt/sources.list.d/kino.sources \\
  $PAGES_URL/kino.sources
sudo apt update
sudo apt install kino</code></pre>

  <h3>Updating</h3>
  <pre><code>sudo apt update &amp;&amp; sudo apt upgrade</code></pre>

  <h3>Or install the single file</h3>
  <p class="lead">No repository, and no automatic updates.</p>
  <pre><code>sudo apt install ./$DEB_FILE</code></pre>

  <h2>What it does</h2>
  <ul class="features">
    <li><strong>Plays everything</strong> — libmpv, so every format FFmpeg reads</li>
    <li><strong>Hardware decode</strong> — VA-API by default, clean software fallback</li>
    <li><strong>Subtitles</strong> — embedded and external, styled ASS via libass</li>
    <li><strong>Desktop native</strong> — media keys, MPRIS, no screen blanking</li>
    <li><strong>Review mode</strong> — frame-exact notes with SMPTE timecode</li>
    <li><strong>Export</strong> — CSV, Markdown or PDF to hand to a contractor</li>
  </ul>
  <p>Everything happens locally: no accounts, no telemetry, no media library and
     no network access. Built against glibc 2.35, so it runs on Ubuntu 22.04+,
     Debian 12+ and anything newer.</p>

  <footer>
    <span>Kino $DEB_VERSION &middot; AGPL-3.0-or-later</span>
    <span><a href="https://github.com/AlpinSuite/kino">Source code</a> &middot;
          <a href="https://github.com/AlpinSuite/kino/releases">All releases</a></span>
  </footer>
</div>
HTML

# GitHub Pages runs Jekyll by default, which would mangle the dists/ tree; this
# disables it.
touch "$OUTPUT/.nojekyll"

echo "APT repository written to $OUTPUT"
find "$OUTPUT/dists" "$OUTPUT/pool" -type f | sort | sed 's/^/  /'
