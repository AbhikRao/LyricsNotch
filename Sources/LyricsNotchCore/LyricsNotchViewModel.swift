import AppKit
import Combine
import SwiftUI

@MainActor
public final class LyricsNotchViewModel: ObservableObject {
    @Published public private(set) var notchState: NotchState = .closed
    @Published public private(set) var notchSize: CGSize
    @Published public private(set) var closedNotchSize: CGSize
    @Published public private(set) var preferredOpenSize: CGSize
    @Published public private(set) var isHovering = false
    @Published public private(set) var hapticToggle = false
    @Published public private(set) var isScrubbing = false
    @Published public private(set) var scrubPosition = 0.0
    @Published public private(set) var spotifyState: SpotifyPlaybackState = .idle
    @Published public private(set) var lyricLines: [LyricLine] = []
    @Published public private(set) var lyricsStatus: LyricsStatus = .idle
    @Published public private(set) var albumArt: NSImage = ArtworkLoader.placeholder
    @Published public private(set) var accentColor: NSColor = .white
    @Published public private(set) var glowColor: NSColor = ColorExtractor.fallbackGlow

    private let lyricsService = LyricsService()
    let cameraManager = CameraManager()
    private var spotifyController: SpotifyController!
    private var lyricsTask: Task<Void, Never>?
    private var artworkTask: Task<Void, Never>?
    private var currentTrackKey = ""
    private var currentArtworkURL = ""
    private var latestArtworkImage: NSImage?
    private var hoverWorkItem: DispatchWorkItem?
    private var closeWorkItem: DispatchWorkItem?
    private var resizeDragStartSize: CGSize?
    private var lyricsEnabled = UserDefaults.standard.object(forKey: "showLyrics") as? Bool ?? true
    private var glowEnabled = UserDefaults.standard.object(forKey: "showGlow") as? Bool ?? true

    public init() {
        let closedSize = NotchMetrics.closedSize()
        notchSize = closedSize
        closedNotchSize = closedSize
        preferredOpenSize = NotchMetrics.persistedOpenSize()

        spotifyController = SpotifyController { [weak self] state in
            self?.handleSpotifyState(state)
        }
    }

    public var shouldShowLyricsPane: Bool {
        lyricsEnabled && lyricsStatus == .synced && !lyricLines.isEmpty
    }

    deinit {
        lyricsTask?.cancel()
        artworkTask?.cancel()
        spotifyController?.stop()
    }

    public func start() {
        spotifyController.start()
    }

    public func stop() {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()
        lyricsTask?.cancel()
        artworkTask?.cancel()
        spotifyController.stop()
    }

    public func open() {
        withAnimation(.bouncy.speed(1.2)) {
            notchSize = targetOpenSize
            notchState = .open
        }
    }

    public func close() {
        withAnimation(.smooth) {
            let closedSize = NotchMetrics.closedSize()
            closedNotchSize = closedSize
            notchSize = closedSize
            notchState = .closed
        }
    }

    public func toggle() {
        switch notchState {
        case .closed:
            open()
        case .open:
            close()
        }
    }

    public func handleHover(_ hovering: Bool, openDelay: TimeInterval) {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()

        if hovering {
            withAnimation(.bouncy.speed(1.2)) {
                isHovering = true
            }

            if notchState == .closed {
                hapticToggle.toggle()
            }

            let task = DispatchWorkItem { [weak self] in
                guard let self, self.isHovering, self.notchState == .closed else { return }
                self.open()
            }
            hoverWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + openDelay, execute: task)
        } else {
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }

                withAnimation(.bouncy.speed(1.2)) {
                    self.isHovering = false
                }

                if self.notchState == .open {
                    self.close()
                }
            }
            closeWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
        }
    }

    public func refreshClosedSize() {
        let size = NotchMetrics.closedSize()
        closedNotchSize = size
        if notchState == .closed {
            notchSize = size
        }
    }

    public func reloadLyrics() {
        guard lyricsEnabled else { return }
        lyricsService.clearCache()
        loadLyrics(for: spotifyState, force: true)
    }

    public func resizeOpenSize(to size: CGSize) {
        let clamped = NotchMetrics.clampedOpenSize(size)
        preferredOpenSize = clamped
        NotchMetrics.saveOpenSize(clamped)

        if notchState == .open, shouldShowLyricsPane {
            notchSize = clamped
        }
    }

    public func updateResizeDrag(translation: CGSize) {
        let base = resizeDragStartSize ?? preferredOpenSize
        resizeDragStartSize = base

        resizeOpenSize(
            to: CGSize(
                width: base.width + translation.width,
                height: base.height + translation.height
            )
        )
    }

    public func endResizeDrag() {
        resizeDragStartSize = nil
    }

    public func beginScrubbing(current: Double) {
        isScrubbing = true
        scrubPosition = current
    }

    public func updateScrubPosition(_ position: Double) {
        scrubPosition = position
    }

    public func endScrubbing() {
        let position = scrubPosition
        isScrubbing = false
        seek(to: position)
    }

    public func setLyricsEnabled(_ enabled: Bool) {
        lyricsEnabled = enabled

        if enabled {
            loadLyrics(for: spotifyState, force: true)
        } else {
            lyricsTask?.cancel()
            lyricLines = []
            lyricsStatus = .idle
            refreshOpenSizeIfNeeded()
        }
    }

    public func setGlowEnabled(_ enabled: Bool) {
        glowEnabled = enabled

        if enabled {
            updateGlow(from: latestArtworkImage)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) {
                glowColor = ColorExtractor.fallbackGlow
            }
        }
    }

    public func togglePlay() {
        spotifyController.togglePlay()
    }

    public func previousTrack() {
        spotifyController.previousTrack()
    }

    public func nextTrack() {
        spotifyController.nextTrack()
    }

    public func toggleShuffle() {
        spotifyController.toggleShuffle()
    }

    public func toggleRepeat() {
        spotifyController.toggleRepeat()
    }

    public func seek(to position: Double) {
        var updated = spotifyState
        updated.position = max(0, min(position, max(spotifyState.duration, 0)))
        updated.lastUpdated = Date()
        spotifyState = updated
        spotifyController.seek(to: position)
    }

    public func playbackTime(at date: Date) -> TimeInterval {
        guard spotifyState.isPlaying else {
            return spotifyState.position
        }

        let smoothed = spotifyState.position + date.timeIntervalSince(spotifyState.lastUpdated)
        if spotifyState.duration > 0 {
            return max(0, min(smoothed, spotifyState.duration))
        }
        return max(0, smoothed)
    }

    public func activeLyricIndex(at time: TimeInterval) -> Int? {
        guard !lyricLines.isEmpty else { return nil }
        let adjustedTime = time + 0.12

        var activeIndex = 0
        for (index, line) in lyricLines.enumerated() where line.time <= adjustedTime {
            activeIndex = index
        }

        return activeIndex
    }

    private func handleSpotifyState(_ state: SpotifyPlaybackState) {
        spotifyState = state

        if state.artworkURL != currentArtworkURL {
            currentArtworkURL = state.artworkURL
            loadArtwork(from: state.artworkURL)
        }

        let nextTrackKey = state.hasTrack ? state.trackKey : ""
        guard nextTrackKey != currentTrackKey else { return }

        currentTrackKey = nextTrackKey
        lyricLines = []
        refreshOpenSizeIfNeeded()

        if state.hasTrack && lyricsEnabled {
            loadLyrics(for: state, force: true)
        } else {
            lyricsTask?.cancel()
            lyricsStatus = state.hasTrack ? .idle : .idle
            refreshOpenSizeIfNeeded()
        }
    }

    private func loadLyrics(for state: SpotifyPlaybackState, force: Bool) {
        guard state.hasTrack, lyricsEnabled else {
            lyricLines = []
            lyricsStatus = state.isRunning ? .notFound : .idle
            return
        }

        let requestKey = state.trackKey
        if !force, requestKey == currentTrackKey, !lyricLines.isEmpty {
            return
        }

        lyricsTask?.cancel()
        lyricsStatus = .loading
        refreshOpenSizeIfNeeded()

        lyricsTask = Task { [weak self] in
            guard let self else { return }

            do {
                let lines = try await lyricsService.syncedLyrics(
                    trackName: state.title,
                    artistName: state.artist,
                    albumName: state.album,
                    duration: state.duration
                )

                guard !Task.isCancelled, self.currentTrackKey == requestKey else { return }
                withAnimation(.smooth) {
                    self.lyricLines = lines
                    self.lyricsStatus = .synced
                }
                self.refreshOpenSizeIfNeeded()
            } catch LyricsServiceError.missingSyncedLyrics {
                guard !Task.isCancelled, self.currentTrackKey == requestKey else { return }
                withAnimation(.smooth) {
                    self.lyricLines = []
                    self.lyricsStatus = .notFound
                }
                self.refreshOpenSizeIfNeeded()
            } catch LyricsServiceError.instrumental {
                guard !Task.isCancelled, self.currentTrackKey == requestKey else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    self.glowColor = ColorExtractor.fallbackGlow
                }
                withAnimation(.smooth) {
                    self.lyricLines = []
                    self.lyricsStatus = .instrumental
                }
                self.refreshOpenSizeIfNeeded()
            } catch {
                guard !Task.isCancelled, self.currentTrackKey == requestKey else { return }
                withAnimation(.smooth) {
                    self.lyricLines = []
                    self.lyricsStatus = .failed("Lyrics unavailable")
                }
                self.refreshOpenSizeIfNeeded()
            }
        }
    }

    private var targetOpenSize: CGSize {
        shouldShowLyricsPane ? preferredOpenSize : NotchMetrics.compactOpenSize
    }

    private func refreshOpenSizeIfNeeded() {
        guard notchState == .open else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
            notchSize = targetOpenSize
        }
    }

    private func loadArtwork(from urlString: String) {
        artworkTask?.cancel()

        guard !urlString.isEmpty else {
            albumArt = ArtworkLoader.placeholder
            accentColor = .white
            latestArtworkImage = nil
            withAnimation(.easeInOut(duration: 1.0)) {
                glowColor = ColorExtractor.fallbackGlow
            }
            return
        }

        let requestedURL = urlString
        artworkTask = Task { [weak self] in
            let image = await ArtworkLoader.load(urlString: requestedURL)
            guard !Task.isCancelled,
                  let self,
                  self.currentArtworkURL == requestedURL else { return }

            let nextImage = image ?? ArtworkLoader.placeholder
            self.latestArtworkImage = image
            let extractedColor = self.glowEnabled ? ArtworkLoader.dominantColor(from: image) : .white
            withAnimation(.smooth) {
                self.albumArt = nextImage
                self.accentColor = extractedColor
            }
            self.updateGlow(from: image)
        }
    }

    private func updateGlow(from image: NSImage?) {
        guard glowEnabled else {
            glowColor = ColorExtractor.fallbackGlow
            return
        }

        let nextColor = image == nil
            ? ColorExtractor.fallbackGlow
            : ArtworkLoader.dominantColor(from: image)

        withAnimation(.easeInOut(duration: 1.0)) {
            glowColor = nextColor
        }
    }
}
