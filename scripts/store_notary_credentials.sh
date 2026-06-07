#!/usr/bin/env bash
set -euo pipefail

PROFILE="${NOTARY_PROFILE:-LyricsNotchNotary}"

echo "Storing Apple notarization credentials in Keychain profile: $PROFILE"
echo "Use your Apple ID, Team ID, and an app-specific password."

if [[ -n "${APPLE_ID:-}" && -n "${TEAM_ID:-}" && -n "${APP_SPECIFIC_PASSWORD:-}" ]]; then
  xcrun notarytool store-credentials "$PROFILE" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "$APP_SPECIFIC_PASSWORD"
else
  xcrun notarytool store-credentials "$PROFILE"
fi
