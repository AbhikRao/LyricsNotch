# LyricsNotch

LyricsNotch is a standalone macOS notch app for Spotify synchronized lyrics. It keeps the Boring Notch-style black island, real-notch sizing, hover expansion, album-art glow, smooth animations, and an optional camera preview.

## Build

```bash
swift build -c release
```

## Package An App Bundle

```bash
chmod +x scripts/package_app.sh
./scripts/package_app.sh
open .build/LyricsNotch.app
```

## Package A DMG

```bash
chmod +x scripts/package_dmg.sh
./scripts/package_dmg.sh
```

The release image and SHA-256 checksum are written to `dist/`. The DMG opens
with `LyricsNotch.app`, an Applications shortcut, and a background prompt that
says to drag the app to Applications and then double click to open.

## Install The Free Community Build

This project currently ships as a free ad-hoc signed community build, not an
Apple-notarized paid Developer ID build.

1. Download and open `LyricsNotch-0.1.0-arm64.dmg`.
2. Drag `LyricsNotch.app` onto the Applications shortcut.
3. In Applications, right-click `LyricsNotch.app` and choose **Open**.
4. Confirm **Open** if macOS shows the unidentified developer warning.
5. Allow Spotify Automation access when macOS asks.

Advanced users can remove Gatekeeper quarantine from an installed copy with:

```bash
xattr -dr com.apple.quarantine /Applications/LyricsNotch.app
open /Applications/LyricsNotch.app
```

## Notarized Release

Notarization requires an Apple Developer account, a `Developer ID Application`
certificate in Keychain, and an app-specific password for App Store Connect.

Store notarization credentials once:

```bash
export APPLE_ID="you@example.com"
export TEAM_ID="TEAMID"
export APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx"
./scripts/store_notary_credentials.sh
```

Build, submit, staple, and checksum a notarized DMG:

```bash
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./scripts/release_notarized_dmg.sh
```

The notarized release image and its SHA-256 checksum are written to `dist/`.
The DMG is signed with hardened runtime, submitted with `notarytool`, stapled
with Apple's ticket, and then checksummed after stapling.

To package without notarization for local testing:

```bash
./scripts/package_dmg.sh
```

That local-testing build is ad-hoc signed and may require right-clicking
**Open** on first launch.

On first Spotify access, macOS should ask for Automation permission. Lyrics are fetched from LRCLIB using `https://lrclib.net/api/search`.

## License

GPL-3.0-compatible derivative of Boring Notch. See `NOTICE.md`.
