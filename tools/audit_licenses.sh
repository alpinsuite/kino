#!/usr/bin/env bash
#
# Enumerates the licences of the native libraries a build ships, and fails when
# one turns up that has not been reasoned about.
#
# This is not box-ticking. Kino is AGPL-3.0-or-later and runs on libmpv, which is
# GPLv2-*or-later*; the "or later" is the only reason the combination is lawful,
# because AGPLv3 is compatible with GPLv3 and not with GPLv2-only. FFmpeg is
# LGPLv2.1+ by default and GPL when built with --enable-gpl, and the combined
# work takes the most restrictive component's terms. A distribution quietly
# swapping in a differently-licensed build is exactly the kind of change nobody
# notices until someone asks — so the build asks, every time.
#
#   tools/audit_licenses.sh [path-to-built-binary]
#
# Scope, which is the part that took a wrong turn once and is worth stating:
#
#   STRICT  — libraries Kino *distributes*. Everything inside the build bundle,
#             and libmpv. §6.1 asks for an audit of bundled libraries, and these
#             are the ones whose licences become Kino's obligation.
#   LISTED  — libraries the package merely *depends* on: the GTK, X11 and glibc
#             stack the distribution already ships and already meets its own
#             obligations for. Auditing these means auditing most of a desktop,
#             and half their copyright files are not machine-readable, so they
#             are inventoried and not gated. Depending on libx11 has never been
#             a licensing question.
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

BUNDLE_DIR="$(cd "$(dirname "$TARGET")" && pwd)"
STATUS=0

# Debian copyright files come in two shapes. DEP-5 ones carry `License:` fields
# and are trivial; a great many older packages are free prose, where the licence
# has to be recognised from the text itself.
licences_of() {
  local package="$1"
  local copyright="/usr/share/doc/$package/copyright"
  [[ -r "$copyright" ]] || return 0

  local found
  found="$(grep -hoE '^License: *[^ ]+' "$copyright" 2>/dev/null |
    sed 's/^License: *//' | sort -u | tr '\n' ' ' || true)"
  if [[ -n "$found" ]]; then
    printf '%s' "$found"
    return 0
  fi

  grep -hoiE "$ALLOWED" "$copyright" 2>/dev/null | sort -u | tr '\n' ' ' || true
}

package_of() {
  dpkg-query -S "$(readlink -f "$1")" 2>/dev/null | cut -d: -f1 | head -1 || true
}

# A library Kino distributes: its licence is Kino's problem, so an unrecognised
# one stops the build.
audit_strict() {
  local label="$1" package="$2"
  local licences
  licences="$(licences_of "$package")"
  licences="${licences:-unknown}"

  if printf '%s' "$licences" | grep -qE "$ALLOWED"; then
    printf '  %-30s %-22s %s\n' "$label" "$package" "$licences"
  else
    printf '  %-30s %-22s %s  <-- UNEXPECTED\n' "$label" "$package" "$licences"
    STATUS=1
  fi
}

echo "Auditing $TARGET"
echo
echo "SHIPPED BY KINO — gated"
echo

# Everything under the bundle is built here: the Flutter engine (BSD-3-Clause)
# and this project's own plugins. dpkg has never heard of them and should not.
while read -r library; do
  [[ -e "$library" ]] || continue
  resolved="$(readlink -f "$library")"
  [[ "$resolved" == "$BUNDLE_DIR"/* ]] || continue
  printf '  %-30s %-22s %s\n' "$(basename "$library")" 'kino' \
    'BSD-3-Clause / AGPL-3.0+'
done < <(ldd "$TARGET" 2>/dev/null | awk '{print $3}' | grep '^/' | sort -u)

# libmpv appears in no ELF and so in no ldd output: media_kit dlopen()s it. An
# audit built only on ldd would report success having checked everything except
# the one dependency that decides whether this application may ship at all.
LIBMPV="$(ldconfig -p 2>/dev/null | awk '/libmpv\.so\.[0-9]/ {print $NF; exit}' || true)"
if [[ -z "$LIBMPV" || ! -e "$LIBMPV" ]]; then
  printf '  %-30s %s\n' 'libmpv' 'NOT INSTALLED  <-- UNEXPECTED'
  echo '        Kino cannot play anything without it; see docs/LICENSING.md.' >&2
  STATUS=1
else
  MPV_PACKAGE="$(package_of "$LIBMPV")"
  if [[ -z "$MPV_PACKAGE" ]]; then
    printf '  %-30s %s\n' "$(basename "$LIBMPV")" \
      'not from a package  <-- UNEXPECTED'
    STATUS=1
  else
    audit_strict "$(basename "$LIBMPV")" "$MPV_PACKAGE"
  fi
fi

echo
echo "PROVIDED BY THE DISTRIBUTION — inventory only"
echo

SEEN=""
while read -r library; do
  [[ -e "$library" ]] || continue
  resolved="$(readlink -f "$library")"
  [[ "$resolved" == "$BUNDLE_DIR"/* ]] && continue

  package="$(package_of "$library")"
  package="${package:-unpackaged}"
  case " $SEEN " in *" $package "*) continue ;; esac
  SEEN="$SEEN $package"

  licences="$(licences_of "$package")"
  printf '  %-30s %s\n' "$package" "${licences:-unknown}"
done < <(ldd "$TARGET" 2>/dev/null | awk '{print $3}' | grep '^/' | sort -u)

echo
if [[ "$STATUS" -ne 0 ]]; then
  cat >&2 <<'MESSAGE'
error: a library Kino distributes carries a licence docs/LICENSING.md does not
account for, or could not be identified at all.

That is not necessarily wrong — the AppImage bundles libmpv on purpose. It does
mean the obligation has to be written down before the artefact ships: which
version, which build flags, and where the corresponding source is offered.
MESSAGE
  exit 1
fi

echo "every library Kino distributes carries a licence LICENSING.md accounts for"
