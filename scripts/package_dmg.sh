#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Packaging/Info.plist")"
ARCH="$(uname -m)"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
DIST_DIR="$ROOT/dist"
DMG_PATH="$DIST_DIR/LyricsNotch-$VERSION-$ARCH.dmg"
CHECKSUM_PATH="$DMG_PATH.sha256"
STAGING_DIR="$(mktemp -d "$ROOT/.build/LyricsNotch-dmg.XXXXXX")"
RW_DMG_PATH="$ROOT/.build/LyricsNotch-$VERSION-$ARCH-rw.dmg"
BACKGROUND_DIR="$STAGING_DIR/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/dmg-background.png"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" && -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGING_DIR"
  rm -f "$RW_DMG_PATH"
}
trap cleanup EXIT

"$ROOT/scripts/package_app.sh" >/dev/null

mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH" "$CHECKSUM_PATH" "$RW_DMG_PATH"

/usr/bin/ditto "$ROOT/.build/LyricsNotch.app" "$STAGING_DIR/LyricsNotch.app"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$BACKGROUND_DIR"
swift "$ROOT/scripts/make_dmg_background.swift" "$BACKGROUND_PATH"

if command -v xattr >/dev/null 2>&1; then
  xattr -cr "$STAGING_DIR"
fi

hdiutil create \
  -volname "LyricsNotch" \
  -srcfolder "$STAGING_DIR" \
  -format UDRW \
  -fs APFS \
  -ov \
  "$RW_DMG_PATH" >/dev/null

MOUNT_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG_PATH")"
MOUNT_POINT="$(printf '%s\n' "$MOUNT_OUTPUT" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
  echo "Failed to mount temporary DMG." >&2
  echo "$MOUNT_OUTPUT" >&2
  exit 1
fi

osascript - "$MOUNT_POINT" <<'APPLESCRIPT'
on run argv
  set mountedVolume to item 1 of argv
  set backgroundAlias to POSIX file (mountedVolume & "/.background/dmg-background.png") as alias

  tell application "Finder"
    tell disk "LyricsNotch"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set bounds of container window to {200, 120, 920, 540}
      set viewOptions to icon view options of container window
      set arrangement of viewOptions to not arranged
      set icon size of viewOptions to 96
      set background picture of viewOptions to backgroundAlias
      set position of item "LyricsNotch.app" to {190, 190}
      set position of item "Applications" to {530, 190}
      update without registering applications
      delay 1
      close
    end tell
  end tell
end run
APPLESCRIPT

sync
hdiutil detach "$MOUNT_POINT" >/dev/null

hdiutil convert "$RW_DMG_PATH" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null

if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$CODE_SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "$DMG_PATH"
echo "$CHECKSUM_PATH"
