#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

swift build -c "$CONFIGURATION" --package-path "$ROOT"
BIN_DIR="$(swift build -c "$CONFIGURATION" --package-path "$ROOT" --show-bin-path)"

APP_PATH="$ROOT/.build/LyricsNotch.app"
CONTENTS="$APP_PATH/Contents"

rm -rf "$APP_PATH"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Packaging/LyricsNotch.icns" "$CONTENTS/Resources/LyricsNotch.icns"
cp "$BIN_DIR/LyricsNotch" "$CONTENTS/MacOS/LyricsNotch"
printf "APPL????" > "$CONTENTS/PkgInfo"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_PATH"
fi

CODE_SIGN_ARGS=(--force --deep --sign "$CODE_SIGN_IDENTITY")
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_ARGS+=(--options runtime --timestamp)
fi
CODE_SIGN_ARGS+=(--entitlements "$ROOT/Packaging/LyricsNotch.entitlements" "$APP_PATH")

codesign "${CODE_SIGN_ARGS[@]}"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$APP_PATH"
fi

echo "$APP_PATH"
