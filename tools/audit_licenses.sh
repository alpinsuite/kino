#!/usr/bin/env bash
#
# Enumerates the licences of the native libraries a build links against, and
# fails when one turns up that has not been reasoned about.
#
# This is not box-ticking. Kino is AGPL-3.0-or-later linked against libmpv,
# which is GPLv2-*or-later*; the "or later" is the only reason the combination
# is lawful, because AGPLv3 is compatible with GPLv3 and not with GPLv2-only.
# FFmpeg is LGPLv2.1+ by default and GPL when built with --enable-gpl, and the
# combined work takes the most restrictive component's terms. A distribution
# quietly swapping in a differently-licensed build is exactly the kind of change
# nobody notices until someone asks — so the build asks, every time.
#
#   tools/audit_licenses.sh [path-to-binary-or-bundle]
#
# See docs/LICENSING.md for what each verdict means.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

TARGET="${1:-build/linux/x64/release/bundle/kino}"

if [[ ! -e "$TARGET" ]]; then
  echo "nothing to audit at $TARGET — run 'flutter build linux --release'" >&2
  exit 1
fi

if ! command -v dpkg-query > /dev/null 2>&1; then
  echo "dpkg-query is unavailable; the audit only runs on a Debian-family host" >&2
  exit 1
fi

# Licences that have been reasoned about in docs/LICENSING.md and are compatible
# with shipping an AGPL-3.0-or-later application. A new entry here is a
# deliberate act that belongs in the same commit as the reasoning.
ALLOWED='GPL-2|GPL-3|LGPL-2|LGPL-3|MIT|BSD|Apache-2|ISC|Zlib|MPL-2|X11|Expat|libpng|FTL|OFL'

echo "Auditing $TARGET"
echo

STATUS=0
SEEN=""

# Anything under here is shipped by Kino itself — the Flutter engine and this
# project's own plugins. dpkg knows nothing about them and should not: their
# licensing is the project's own, recorded in docs/LICENSING.md, and flagging
# them as "unexpected" would make the audit fail on every correct build.
BUNDLE_DIR="$(cd "$(dirname "$TARGET")" && pwd)"

report_package() {
  local package="$1"
  case " $SEEN " in *" $package "*) return 0 ;; esac
  SEEN="$SEEN $package"

  local copyright="/usr/share/doc/$package/copyright"
  local licences
  licences="$(grep -hoE '^License: *[^ ]+' "$copyright" 2>/dev/null |
    sed 's/^License: *//' | sort -u | tr '\n' ' ' || true)"
  licences="${licences:-unknown}"

  if printf '%s' "$licences" | grep -qE "$ALLOWED"; then
    printf '  %-34s %s\n' "$package" "$licences"
  else
    printf '  %-34s %s  <-- UNEXPECTED\n' "$package" "$licences"
    STATUS=1
  fi
}

while read -r library; do
  [[ -e "$library" ]] || continue

  resolved="$(readlink -f "$library")"
  if [[ "$resolved" == "$BUNDLE_DIR"/* ]]; then
    printf '  %-34s %s\n' "$(basename "$library")" 'shipped by Kino'
    continue
  fi

  package="$(dpkg-query -S "$resolved" 2>/dev/null | cut -d: -f1 | head -1 || true)"
  if [[ -z "$package" ]]; then
    printf '  %-34s %s\n' "$(basename "$library")" \
      'not from a package — BUNDLED'
    STATUS=1
    continue
  fi

  report_package "$package"
done < <(ldd "$TARGET" 2>/dev/null | awk '{print $3}' | grep '^/' | sort -u)

# libmpv never appears above, and it is the one licence that actually decides
# whether this application may ship at all.
#
# media_kit dlopen()s it, so it is absent from the ELF and invisible to ldd. An
# audit that silently skipped the GPL-2.0-or-later dependency an AGPL
# application hangs off would be worse than no audit — it would report success
# having checked nothing that mattered.
echo
LIBMPV="$(ldconfig -p 2>/dev/null | awk '/libmpv\.so\.[0-9]/ {print $NF; exit}' || true)"
if [[ -z "$LIBMPV" || ! -e "$LIBMPV" ]]; then
  echo '  libmpv                             NOT INSTALLED  <-- UNEXPECTED' >&2
  echo '        Kino cannot play anything without it; see docs/LICENSING.md.' >&2
  STATUS=1
else
  MPV_PACKAGE="$(dpkg-query -S "$(readlink -f "$LIBMPV")" 2>/dev/null |
    cut -d: -f1 | head -1 || true)"
  if [[ -z "$MPV_PACKAGE" ]]; then
    printf '  %-34s %s\n' "$(basename "$LIBMPV")" \
      'not from a package — BUNDLED'
    STATUS=1
  else
    report_package "$MPV_PACKAGE"
  fi
fi

echo
if [[ "$STATUS" -ne 0 ]]; then
  cat >&2 <<'MESSAGE'
error: a linked library carries a licence that docs/LICENSING.md does not
account for, or is bundled rather than provided by a package.

Neither is necessarily wrong — the AppImage bundles libmpv on purpose. It does
mean the obligation has to be written down before the artefact ships: which
version, which build flags, where the corresponding source is offered.
MESSAGE
  exit 1
fi

echo "every linked library carries a licence docs/LICENSING.md accounts for"
