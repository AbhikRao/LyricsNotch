import AppKit
import LyricsNotchCore

@main
struct LyricsNotchLauncher {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = LyricsNotchAppDelegate()

        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
