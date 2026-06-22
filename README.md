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

Public DMG distribution is paused for now. The packaging script is still kept in the repo for future releases:

```bash
chmod +x scripts/package_dmg.sh
./scripts/package_dmg.sh
```

## Install From Source

Build the app bundle locally:

```bash
./scripts/package_app.sh
open .build/LyricsNotch.app
```

On first Spotify access, macOS should ask for Automation permission.

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

Lyrics are fetched from LRCLIB using `https://lrclib.net/api/search`.

## Website

The landing page is live at `https://lyricsnotch.vercel.app`.

The source lives in `website/` and is deployed with Vercel. Open
`website/index.html` directly or serve the folder locally:

```bash
cd website
npm run preview
```

Deploy to Vercel:

```bash
cd website
npm run deploy
```

## License

GPL-3.0-compatible derivative of Boring Notch. See `NOTICE.md`.
