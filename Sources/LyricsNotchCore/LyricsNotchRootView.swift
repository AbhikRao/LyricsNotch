import AppKit
import SwiftUI

struct LyricsNotchRootView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    @AppStorage("showLyrics") private var showLyrics = true
    @AppStorage("showGlow") private var showGlow = true
    @AppStorage("showCamera") private var showCamera = false

    private let hoverDelay: TimeInterval = 0.45

    var body: some View {
        ZStack(alignment: .top) {
            vibeGlow

            island
                .onHover { hovering in
                    viewModel.handleHover(hovering, openDelay: hoverDelay)
                }
                .onTapGesture {
                    viewModel.toggle()
                }
        }
        .frame(
            width: NotchMetrics.hostPanelSize.width,
            height: NotchMetrics.hostPanelSize.height,
            alignment: .top
        )
        .padding(.bottom, 8)
        .shadow(
            color: (viewModel.notchState == .open || viewModel.isHovering)
                ? .black.opacity(0.22)
                : .clear,
            radius: viewModel.notchState == .open ? 6 : 4
        )
        .sensoryFeedback(.alignment, trigger: viewModel.hapticToggle)
        .onAppear {
            viewModel.setLyricsEnabled(showLyrics)
            viewModel.setGlowEnabled(showGlow)
            viewModel.setCameraEnabled(showCamera)
        }
        .onChange(of: showLyrics) { _, enabled in
            viewModel.setLyricsEnabled(enabled)
        }
        .onChange(of: showGlow) { _, enabled in
            viewModel.setGlowEnabled(enabled)
        }
        .onChange(of: showCamera) { _, enabled in
            viewModel.setCameraEnabled(enabled)
        }
    }

    private var island: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                header

                if viewModel.notchState == .open {
                    expandedContent
                        .transition(
                            .opacity
                                .combined(with: .move(edge: .top))
                        )
                }
            }
            .frame(
                width: viewModel.notchSize.width,
                height: viewModel.notchSize.height,
                alignment: .top
            )
            .background(Color.black)
            .mask {
                notchMask
            }
            .overlay(alignment: .bottomTrailing) {
                if viewModel.notchState == .open, usesFullLayout {
                    ResizeHandle(viewModel: viewModel)
                        .padding(.trailing, 12)
                        .padding(.bottom, 10)
                }
            }
        }
        .offset(y: openGap)
        .shadow(
            color: viewModel.notchState == .open ? .black.opacity(0.38) : .clear,
            radius: usesFullLayout ? 18 : 10,
            y: usesFullLayout ? 8 : 4
        )
        .animation(.bouncy.speed(1.2), value: viewModel.isHovering)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: viewModel.notchState)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: viewModel.notchSize)
    }

    private var vibeGlow: some View {
        NotchShape(
            topCornerRadius: viewModel.notchState == .open
                ? NotchMetrics.openCornerRadii.top
                : NotchMetrics.closedCornerRadii.top,
            bottomCornerRadius: viewModel.notchState == .open
                ? NotchMetrics.openCornerRadii.bottom
                : NotchMetrics.closedCornerRadii.bottom
        )
        .fill(Color(nsColor: viewModel.glowColor))
        .frame(
            width: viewModel.notchSize.width + 16,
            height: viewModel.notchSize.height + 12,
            alignment: .top
        )
        .mask {
            glowLeakMask
        }
        .blur(radius: 18)
        .blendMode(.screen)
        .opacity(viewModel.spotifyState.isPlaying && showGlow && !viewModel.isHovering ? 0.25 : 0)
        .offset(y: openGap + 2)
        .allowsHitTesting(false)
        .animation(.easeInOut(duration: 1.0), value: viewModel.glowColor)
        .animation(.easeInOut(duration: 0.35), value: viewModel.spotifyState.isPlaying)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: viewModel.notchSize)
    }

    private var glowLeakMask: some View {
        ZStack {
            NotchShape(
                topCornerRadius: viewModel.notchState == .open
                    ? NotchMetrics.openCornerRadii.top
                    : NotchMetrics.closedCornerRadii.top,
                bottomCornerRadius: viewModel.notchState == .open
                    ? NotchMetrics.openCornerRadii.bottom
                    : NotchMetrics.closedCornerRadii.bottom
            )
            .fill(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.12), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            NotchShape(
                topCornerRadius: viewModel.notchState == .open
                    ? NotchMetrics.openCornerRadii.top
                    : NotchMetrics.closedCornerRadii.top,
                bottomCornerRadius: viewModel.notchState == .open
                    ? NotchMetrics.openCornerRadii.bottom
                    : NotchMetrics.closedCornerRadii.bottom
            )
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .clear, location: 0.22),
                        .init(color: .clear, location: 0.78),
                        .init(color: .black, location: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(0.7)
        }
        .frame(
            width: viewModel.notchSize.width + 16,
            height: viewModel.notchSize.height + 12
        )
    }

    private var notchMask: some View {
        NotchShape(
            topCornerRadius: viewModel.notchState == .open
                ? NotchMetrics.openCornerRadii.top
                : NotchMetrics.closedCornerRadii.top,
            bottomCornerRadius: viewModel.notchState == .open
                ? NotchMetrics.openCornerRadii.bottom
                : NotchMetrics.closedCornerRadii.bottom
        )
        .drawingGroup()
    }

    private var header: some View {
        ZStack {
            if viewModel.notchState == .closed {
                ClosedLiveActivity(viewModel: viewModel, isHovering: viewModel.isHovering)
            } else {
                Color.clear
            }
        }
        .frame(
            width: viewModel.notchState == .open
                ? viewModel.notchSize.width
                : viewModel.closedNotchSize.width,
            height: headerHeight,
            alignment: .center
        )
    }

    private var headerHeight: CGFloat {
        viewModel.notchState == .open
            ? 0
            : max(1, viewModel.closedNotchSize.height + (viewModel.isHovering ? 6 : 0))
    }

    private var usesFullLayout: Bool {
        viewModel.shouldShowLyricsPane || showCamera
    }

    private var openGap: CGFloat {
        guard viewModel.notchState == .open else { return 0 }
        return usesFullLayout ? NotchMetrics.floatingOpenGap : NotchMetrics.compactFloatingOpenGap
    }

    private var expandedContent: some View {
        Group {
            if usesFullLayout {
                fullSpotifyLayout
            } else {
                compactSpotifyLayout
            }
        }
        .padding(.horizontal, usesFullLayout ? 22 : 16)
        .padding(.bottom, usesFullLayout ? 18 : 12)
        .frame(
            width: viewModel.notchSize.width,
            height: max(1, viewModel.notchSize.height - headerHeight),
            alignment: .center
        )
        .blur(radius: viewModel.notchState == .closed ? 24 : 0)
    }

    private var fullSpotifyLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtworkView(viewModel: viewModel, artworkSize: 92)
                .frame(width: 112, height: 112)

            TrackControlsView(viewModel: viewModel)
                .frame(width: 198, height: 120)

            ExpandedContentPane(
                viewModel: viewModel,
                showLyrics: viewModel.shouldShowLyricsPane,
                showCamera: showCamera
            )
            .frame(maxWidth: .infinity, minHeight: 116, maxHeight: .infinity)
        }
    }

    private var compactSpotifyLayout: some View {
        HStack(alignment: .center, spacing: 14) {
            ArtworkView(viewModel: viewModel, artworkSize: 64)
                .frame(width: 76, height: 76)

            CompactTrackControlsView(viewModel: viewModel)
                .frame(width: 324, height: 86)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

}

private struct ClosedLiveActivity: View {
    @ObservedObject var viewModel: LyricsNotchViewModel
    let isHovering: Bool

    var body: some View {
        HStack(spacing: 8) {
            if viewModel.spotifyState.hasTrack {
                Image(nsImage: viewModel.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(
                        width: max(12, viewModel.closedNotchSize.height - 12),
                        height: max(12, viewModel.closedNotchSize.height - 12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))

                Spacer(minLength: 0)

                AudioBars(
                    isPlaying: viewModel.spotifyState.isPlaying,
                    color: Color(nsColor: viewModel.accentColor)
                )
                .frame(width: 18, height: 14)
            } else {
                Color.clear
            }
        }
        .padding(.horizontal, 6)
        .frame(
            width: viewModel.closedNotchSize.width,
            height: viewModel.closedNotchSize.height + (isHovering ? 6 : 0)
        )
    }
}

private struct ArtworkView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel
    var artworkSize: CGFloat = 92

    var body: some View {
        Button {
            SpotifyLauncher.open()
        } label: {
            artworkStack
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .help("Open Spotify")
    }

    private var artworkStack: some View {
        ZStack {
            if viewModel.spotifyState.hasTrack {
                Image(nsImage: viewModel.albumArt)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: artworkSize + 4, height: artworkSize + 4)
                    .clipShape(RoundedRectangle(cornerRadius: max(10, artworkSize * 0.15), style: .continuous))
                    .scaleEffect(1.38)
                    .rotationEffect(.degrees(92))
                    .blur(radius: 40)
                    .opacity(viewModel.spotifyState.isPlaying ? 0.52 : 0.18)
            }

            Image(nsImage: viewModel.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: artworkSize, height: artworkSize)
                .clipShape(RoundedRectangle(cornerRadius: max(10, artworkSize * 0.14), style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: max(10, artworkSize * 0.14), style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                .scaleEffect(viewModel.spotifyState.isPlaying ? 1 : 0.92)
        }
        .frame(width: artworkSize + 20, height: artworkSize + 20)
    }
}

private struct ExpandedContentPane: View {
    @ObservedObject var viewModel: LyricsNotchViewModel
    let showLyrics: Bool
    let showCamera: Bool

    var body: some View {
        Group {
            if showCamera && showLyrics {
                HStack(spacing: 10) {
                    CameraPreview(showCamera: showCamera, manager: viewModel.cameraManager)
                        .frame(width: 98, height: 82)

                    LyricsPanelView(viewModel: viewModel)
                }
            } else if showCamera {
                CameraPreview(showCamera: showCamera, manager: viewModel.cameraManager)
            } else if showLyrics {
                LyricsPanelView(viewModel: viewModel)
            } else {
                AmbientOnlyPane(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ResizeHandle: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white.opacity(0.36))
            .frame(width: 24, height: 24)
            .background {
                Circle()
                    .fill(.white.opacity(0.055))
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                    }
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        viewModel.updateResizeDrag(translation: value.translation)
                    }
                    .onEnded { _ in
                        viewModel.endResizeDrag()
                    }
            )
            .help("Drag to resize")
    }
}

private struct AmbientOnlyPane: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        VStack(spacing: 12) {
            AudioBars(
                isPlaying: viewModel.spotifyState.isPlaying,
                color: Color(nsColor: viewModel.accentColor)
            )
            .frame(width: 92, height: 32)

            Text(viewModel.spotifyState.hasTrack ? "Listening" : "Open Spotify")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.52))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CompactTrackControlsView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            VStack(alignment: .leading, spacing: 0) {
                Text(viewModel.spotifyState.title.isEmpty ? "Spotify" : viewModel.spotifyState.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(viewModel.spotifyState.artist.isEmpty ? statusSubtitle : viewModel.spotifyState.artist)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: viewModel.accentColor).opacity(0.86))
                    .lineLimit(1)
            }
            .frame(height: 28, alignment: .topLeading)

            CompactProgressSlider(viewModel: viewModel)

            HStack(spacing: 7) {
                IconButton(
                    systemName: "shuffle",
                    size: 23,
                    isActive: viewModel.spotifyState.isShuffled,
                    accentColor: viewModel.accentColor,
                    help: "Shuffle",
                    action: viewModel.toggleShuffle
                )

                IconButton(
                    systemName: "backward.fill",
                    size: 23,
                    help: "Previous",
                    action: viewModel.previousTrack
                )

                IconButton(
                    systemName: viewModel.spotifyState.isPlaying ? "pause.fill" : "play.fill",
                    size: 29,
                    help: viewModel.spotifyState.isPlaying ? "Pause" : "Play",
                    action: viewModel.togglePlay
                )

                IconButton(
                    systemName: "forward.fill",
                    size: 23,
                    help: "Next",
                    action: viewModel.nextTrack
                )

                IconButton(
                    systemName: "repeat",
                    size: 23,
                    isActive: viewModel.spotifyState.repeatMode == .all,
                    accentColor: viewModel.accentColor,
                    help: "Repeat",
                    action: viewModel.toggleRepeat
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var statusSubtitle: String {
        if !viewModel.spotifyState.isRunning {
            return "Open Spotify"
        }

        if !viewModel.spotifyState.isPlaying {
            return "Paused"
        }

        return "Listening"
    }
}

private struct CompactProgressSlider: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: viewModel.spotifyState.isPlaying ? 0.12 : nil)) { timeline in
            let duration = max(1, viewModel.spotifyState.duration)
            let current = viewModel.playbackTime(at: timeline.date)
            let progress = min(max(current / duration, 0), 1)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))

                Capsule()
                    .fill(Color(nsColor: viewModel.accentColor).opacity(0.76))
                    .frame(width: max(5, 292 * progress))
            }
        }
        .frame(width: 292, height: 5)
    }
}

private struct TrackControlsView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(viewModel.spotifyState.title.isEmpty ? "Spotify" : viewModel.spotifyState.title)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(viewModel.spotifyState.artist.isEmpty ? statusSubtitle : viewModel.spotifyState.artist)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(nsColor: viewModel.accentColor))
                    .lineLimit(1)
            }
            .frame(height: 34, alignment: .topLeading)

            ProgressSlider(viewModel: viewModel)

            HStack(spacing: 8) {
                IconButton(
                    systemName: "shuffle",
                    isActive: viewModel.spotifyState.isShuffled,
                    accentColor: viewModel.accentColor,
                    help: "Shuffle",
                    action: viewModel.toggleShuffle
                )

                IconButton(
                    systemName: "backward.fill",
                    help: "Previous",
                    action: viewModel.previousTrack
                )

                IconButton(
                    systemName: viewModel.spotifyState.isPlaying ? "pause.fill" : "play.fill",
                    size: 34,
                    help: viewModel.spotifyState.isPlaying ? "Pause" : "Play",
                    action: viewModel.togglePlay
                )

                IconButton(
                    systemName: "forward.fill",
                    help: "Next",
                    action: viewModel.nextTrack
                )

                IconButton(
                    systemName: "repeat",
                    isActive: viewModel.spotifyState.repeatMode == .all,
                    accentColor: viewModel.accentColor,
                    help: "Repeat",
                    action: viewModel.toggleRepeat
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var statusSubtitle: String {
        if !viewModel.spotifyState.isRunning {
            return "Open Spotify"
        }

        if !viewModel.spotifyState.isPlaying {
            return "Paused"
        }

        return "Listening"
    }
}

private struct ProgressSlider: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: viewModel.spotifyState.isPlaying ? 0.08 : nil)) { timeline in
            let duration = max(1, viewModel.spotifyState.duration)
            let current = viewModel.playbackTime(at: timeline.date)

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: {
                            viewModel.isScrubbing ? viewModel.scrubPosition : min(current, duration)
                        },
                        set: { newValue in
                            viewModel.updateScrubPosition(newValue)
                        }
                    ),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        if editing {
                            viewModel.beginScrubbing(current: current)
                        } else {
                            viewModel.endScrubbing()
                        }
                    }
                )
                .tint(Color(nsColor: viewModel.accentColor))
                .controlSize(.small)

                HStack {
                    Text(formatTime(viewModel.isScrubbing ? viewModel.scrubPosition : current))
                    Spacer()
                    Text(formatTime(viewModel.spotifyState.duration))
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.38))
            }
        }
        .frame(height: 30)
    }

    private func formatTime(_ value: TimeInterval) -> String {
        guard value.isFinite, value >= 0 else { return "0:00" }
        let totalSeconds = Int(value.rounded(.down))
        return "\(totalSeconds / 60):\(String(format: "%02d", totalSeconds % 60))"
    }
}

private struct LyricsPanelView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    var body: some View {
        TimelineView(.animation(minimumInterval: viewModel.spotifyState.isPlaying ? 0.05 : nil)) { timeline in
            let playbackTime = viewModel.playbackTime(at: timeline.date)
            let activeIndex = viewModel.activeLyricIndex(at: playbackTime)

            ZStack {
                switch viewModel.lyricsStatus {
                case .synced:
                    lyricsStack(activeIndex: activeIndex)
                case .instrumental:
                    noLyricsFallback("Instrumental")
                case .loading:
                    fallback("Finding lyrics")
                case .notFound:
                    noLyricsFallback("No synced lyrics found")
                case .failed(let message):
                    noLyricsFallback(message)
                case .idle:
                    fallback(viewModel.spotifyState.isRunning ? "Spotify paused" : "Open Spotify")
                }
            }
            .animation(.smooth, value: activeIndex)
            .animation(.smooth, value: viewModel.lyricsStatus)
        }
    }

    private func lyricsStack(activeIndex: Int?) -> some View {
        let index = activeIndex ?? 0
        let lowerBound = max(0, index - 1)
        let upperBound = min(viewModel.lyricLines.count - 1, index + 1)
        let visibleLines = Array(viewModel.lyricLines[lowerBound...upperBound])

        return VStack(spacing: 8) {
            ForEach(visibleLines) { line in
                let isActive = line.id == index

                if isActive {
                    Text(line.text)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(viewModel.notchSize.height > 245 ? 5 : 4)
                        .minimumScaleFactor(0.62)
                        .frame(
                            maxWidth: .infinity,
                            minHeight: 54,
                            maxHeight: max(64, viewModel.notchSize.height - 76),
                            alignment: .center
                        )
                        .contentTransition(.opacity)
                        .id(line.id)
                } else {
                    Text(line.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.32))
                        .multilineTextAlignment(.center)
                        .lineLimit(viewModel.notchSize.height > 235 ? 2 : 1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 18, maxHeight: viewModel.notchSize.height > 235 ? 32 : 18, alignment: .center)
                        .scaleEffect(0.98)
                        .blur(radius: 0.2)
                        .id(line.id)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .mask {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .black, location: 0.14),
                    .init(color: .black, location: 0.86),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .contentTransition(.opacity)
    }

    private func fallback(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.52))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func noLyricsFallback(_ text: String) -> some View {
        ZStack {
            Image(nsImage: viewModel.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .blur(radius: 34)
                .scaleEffect(1.3)
                .opacity(viewModel.spotifyState.hasTrack ? 0.34 : 0)

            VStack(spacing: 12) {
                AudioBars(
                    isPlaying: viewModel.spotifyState.isPlaying,
                    color: Color(nsColor: viewModel.accentColor)
                )
                .frame(width: 86, height: 30)

                Text(text)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.62))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }
}

private struct IconButton: View {
    let systemName: String
    var size: CGFloat = 28
    var isActive = false
    var accentColor: NSColor = .white
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size >= 34 ? 13 : 11, weight: .semibold))
                .foregroundStyle(isActive ? Color(nsColor: accentColor) : .white.opacity(0.92))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.13 : 0.07))
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.045), lineWidth: 1)
                        }
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private struct AudioBars: View {
    let isPlaying: Bool
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: isPlaying ? 0.12 : nil)) { timeline in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: barHeight(index: index, date: timeline.date))
                        .opacity(isPlaying ? 0.9 : 0.35)
                }
            }
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        guard isPlaying else { return 4 }
        let phase = date.timeIntervalSinceReferenceDate * 5 + Double(index) * 0.9
        return 5 + CGFloat((sin(phase) + 1) * 4.5)
    }
}
