import AppKit
import SwiftUI

@MainActor
public final class LyricsNotchAppDelegate: NSObject, NSApplicationDelegate {
    private var panel: LyricsNotchPanel?
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let viewModel = LyricsNotchViewModel()

    public override init() {
        super.init()
    }

    public func applicationDidFinishLaunching(_ notification: Notification) {
        createPanel()
        createStatusItem()
        viewModel.start()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenConfigurationDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    public func applicationWillTerminate(_ notification: Notification) {
        viewModel.stop()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenConfigurationDidChange() {
        viewModel.refreshClosedSize()
        positionPanel()
    }

    private func createPanel() {
        let panel = LyricsNotchPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: NotchMetrics.openSize.width,
                height: NotchMetrics.openSize.height
            ),
            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow, .hudWindow],
            backing: .buffered,
            defer: false
        )

        panel.contentView = NSHostingView(
            rootView: LyricsNotchRootView(viewModel: viewModel)
        )
        panel.orderFrontRegardless()
        self.panel = panel
        positionPanel()
    }

    private func positionPanel() {
        guard let panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let frame = screen.frame
        panel.setFrameOrigin(
            NSPoint(
                x: frame.midX - panel.frame.width / 2,
                y: frame.maxY - panel.frame.height
            )
        )
    }

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "music.note.list",
                accessibilityDescription: "LyricsNotch"
            )
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Settings...",
                action: #selector(showSettings),
                keyEquivalent: ","
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Reload Lyrics",
                action: #selector(reloadLyrics),
                keyEquivalent: "r"
            )
        )
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit LyricsNotch",
                action: #selector(quit),
                keyEquivalent: "q"
            )
        )

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func reloadLyrics() {
        viewModel.reloadLyrics()
    }

    @objc private func showSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 190),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.title = "LyricsNotch Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
