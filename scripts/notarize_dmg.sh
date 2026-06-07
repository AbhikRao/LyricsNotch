#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${NOTARY_PROFILE:-LyricsNotchNotary}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Packaging/Info.plist")"
ARCH="$(uname -m)"
DMG_PATH="${1:-$ROOT/dist/LyricsNotch-$VERSION-$ARCH.dmg}"
CHECKSUM_PATH="$DMG_PATH.sha256"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "DMG not found: $DMG_PATH" >&2
  exit 1
fi

if ! codesign --verify --deep --strict --verbose=2 "$DMG_PATH" >/dev/null 2>&1; then
  echo "DMG is not signed with a valid Developer ID identity: $DMG_PATH" >&2
  echo "Rebuild with CODE_SIGN_IDENTITY=\"Developer ID Application: Your Name (TEAMID)\" ./scripts/package_dmg.sh" >&2
  exit 1
fi

xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$PROFILE" \
  --wait

xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

(
  cd "$(dirname "$DMG_PATH")"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
