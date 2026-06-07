import AppKit

@MainActor
enum SpotifyLauncher {
    static func open() {
        activateWithAppleScript()

        guard let spotifyURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.spotify.client"
        ) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: spotifyURL, configuration: configuration) { _, _ in
            activateWithAppleScript()
        }
    }

    nonisolated private static func activateWithAppleScript() {
        Task.detached(priority: .userInitiated) {
            try? AppleScriptHelper.executeVoid("tell application \"Spotify\" to activate")
        }
    }
}
