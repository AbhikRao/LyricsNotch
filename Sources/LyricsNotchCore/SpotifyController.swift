import AppKit
import Foundation

public final class SpotifyController {
    public private(set) var state = SpotifyPlaybackState.idle
    private var pollTask: Task<Void, Never>?
    private let onStateChange: @MainActor (SpotifyPlaybackState) -> Void

    public init(onStateChange: @escaping @MainActor (SpotifyPlaybackState) -> Void) {
        self.onStateChange = onStateChange
    }

    public func start() {
        stop()

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func refresh() async {
        let nextState = await fetchPlaybackState()
        await MainActor.run {
            self.state = nextState
            self.onStateChange(nextState)
        }
    }

    public func togglePlay() {
        runCommand("playpause")
    }

    public func nextTrack() {
        runCommand("next track")
    }

    public func previousTrack() {
        runCommand("previous track")
    }

    public func seek(to position: Double) {
        runCommand("set player position to \(max(0, position))")
    }

    public func toggleShuffle() {
        runCommand("set shuffling to not shuffling")
    }

    public func toggleRepeat() {
        runCommand("set repeating to not repeating")
    }

    private func runCommand(_ command: String) {
        Task { [weak self] in
            _ = try? await Task.detached(priority: .userInitiated) {
                try AppleScriptHelper.executeVoid("tell application \"Spotify\" to \(command)")
            }.value

            try? await Task.sleep(nanoseconds: 180_000_000)
            await self?.refresh()
        }
    }

    private func fetchPlaybackState() async -> SpotifyPlaybackState {
        await Task.detached(priority: .userInitiated) {
            let script = """
            if application "Spotify" is running then
                tell application "Spotify"
                    try
                        set playerState to (player state as string)
                        set currentTrackID to id of current track
                        set currentTrackName to name of current track
                        set currentTrackArtist to artist of current track
                        set currentTrackAlbum to album of current track
                        set trackPosition to player position
                        set trackDuration to duration of current track
                        set shuffleState to shuffling
                        set repeatState to repeating
                        set artworkURL to artwork url of current track
                        return {true, playerState is "playing", currentTrackID, currentTrackName, currentTrackArtist, currentTrackAlbum, trackPosition, trackDuration, shuffleState, repeatState, artworkURL}
                    on error
                        return {true, false, "", "", "", "", 0, 0, false, false, ""}
                    end try
                end tell
            else
                return {false, false, "", "", "", "", 0, 0, false, false, ""}
            end if
            """

            do {
                let descriptor = try AppleScriptHelper.execute(script)
                return Self.playbackState(from: descriptor)
            } catch {
                return .idle
            }
        }.value
    }

    private static func playbackState(from descriptor: NSAppleEventDescriptor) -> SpotifyPlaybackState {
        guard descriptor.numberOfItems >= 11 else {
            return .idle
        }

        return SpotifyPlaybackState(
            isRunning: descriptor.atIndex(1)?.booleanValue ?? false,
            isPlaying: descriptor.atIndex(2)?.booleanValue ?? false,
            trackID: descriptor.atIndex(3)?.stringValue ?? "",
            title: descriptor.atIndex(4)?.stringValue ?? "",
            artist: descriptor.atIndex(5)?.stringValue ?? "",
            album: descriptor.atIndex(6)?.stringValue ?? "",
            position: descriptor.atIndex(7)?.doubleValue ?? 0,
            duration: (descriptor.atIndex(8)?.doubleValue ?? 0) / 1000,
            isShuffled: descriptor.atIndex(9)?.booleanValue ?? false,
            repeatMode: (descriptor.atIndex(10)?.booleanValue ?? false) ? .all : .off,
            artworkURL: descriptor.atIndex(11)?.stringValue ?? "",
            lastUpdated: Date()
        )
    }
}
