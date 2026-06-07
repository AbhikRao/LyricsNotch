#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -z "${CODE_SIGN_IDENTITY:-}" || "${CODE_SIGN_IDENTITY:-}" == "-" ]]; then
  echo "Set CODE_SIGN_IDENTITY to your Developer ID Application certificate." >&2
  echo 'Example: CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_notarized_dmg.sh' >&2
  exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
  export NOTARY_PROFILE="LyricsNotchNotary"
fi

DMG_PATH="$("$ROOT/scripts/package_dmg.sh" | sed -n '1p')"
"$ROOT/scripts/notarize_dmg.sh" "$DMG_PATH"
