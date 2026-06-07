import AppKit
import SwiftUI

struct LyricsNotchRootView: View {
    @ObservedObject var viewModel: LyricsNotchViewModel

    @AppStorage("showLyrics") private var showLyrics = true
    @AppStorage("showGlow") private var showGlow = true
    @AppStorage("showCamera") private var showCamera = false

    @State private var isHovering = false
    @State private var hoverWorkItem: DispatchWorkItem?
    @State private var closeWorkItem: DispatchWorkItem?
    @State private var hapticToggle = false

    private let hoverDelay: TimeInterval = 0.28

    var body: some View {
        ZStack(alignment: .top) {
            vibeGlow

            island
                .onHover(perform: handleHover)
                .onTapGesture {
                    viewModel.toggle()
                }
        }
        .frame(
            width: NotchMetrics.openSize.width,
            height: NotchMetrics.openSize.height,
            alignment: .top
        )
        .padding(.bottom, 8)
        .shadow(
            color: (viewModel.notchState == .open || isHovering)
                ? .black.opacity(0.22)
                : .clear,
            radius: viewModel.notchState == .open ? 6 : 4
        )
        .sensoryFeedback(.alignment, trigger: hapticToggle)
        .onAppear {
            viewModel.setLyricsEnabled(showLyrics)
            viewModel.setGlowEnabled(showGlow)
        }
        .onChange(of: showLyrics) { _, enabled in
            viewModel.setLyricsEnabled(enabled)
        }
        .onChange(of: showGlow) { _, enabled in
            viewModel.setGlowEnabled(enabled)
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
        }
        .animation(.bouncy.speed(1.2), value: isHovering)
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
        .opacity(viewModel.spotifyState.isPlaying && showGlow && !isHovering ? 0.25 : 0)
        .offset(y: 2)
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
                ClosedLiveActivity(viewModel: viewModel, isHovering: isHovering)
            } else {
                Color.clear
            }
        }
        .frame(
            width: viewModel.notchState == .open
                ? viewModel.notchSize.width
                : viewModel.closedNotchSize.width,
            height: max(1, viewModel.closedNotchSize.height + (isHovering ? 6 : 0)),
            alignment: .center
        )
    }

    private var expandedContent: some View {
        HStack(alignment: .center, spacing: 16) {
            ArtworkView(viewModel: viewModel)
                .frame(width: 112, height: 112)

            TrackControlsView(viewModel: viewModel)
                .frame(width: 198, height: 120)

            ExpandedContentPane(
                viewModel: viewModel,
                showLyrics: showLyrics,
                showCamera: showCamera
            )
            .frame(maxWidth: .infinity, minHeight: 116, maxHeight: 124)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
        .frame(
            width: NotchMetrics.openSize.width,
            height: NotchMetrics.openSize.height - max(1, viewModel.closedNotchSize.height),
            alignment: .center
        )
        .blur(radius: viewModel.notchState == .closed ? 24 : 0)
    }

    private func handleHover(_ hovering: Bool) {
        hoverWorkItem?.cancel()
        closeWorkItem?.cancel()

        if hovering {
            withAnimation(.bouncy.speed(1.2)) {
                isHovering = true
            }

            if viewModel.notchState == .closed {
                hapticToggle.toggle()
            }

            let task = DispatchWorkItem {
                guard isHovering, viewModel.notchState == .closed else { return }
                viewModel.open()
            }
            hoverWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + hoverDelay, execute: task)
        } else {
            let task = DispatchWorkItem {
                withAnimation(.bouncy.speed(1.2)) {
                    isHovering = false
                }

                if viewModel.notchState == .open {
                    viewModel.close()
                }
            }
            closeWorkItem = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: task)
        }
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
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .scaleEffect(1.38)
                    .rotationEffect(.degrees(92))
                    .blur(radius: 40)
                    .opacity(viewModel.spotifyState.isPlaying ? 0.52 : 0.18)
            }

            Image(nsImage: viewModel.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.45), radius: 12, y: 6)
                .scaleEffect(viewModel.spotifyState.isPlaying ? 1 : 0.92)
        }
        .frame(width: 112, height: 112)
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
                    CameraPreview(showCamera: showCamera)
                        .frame(width: 98, height: 82)

                    LyricsPanelView(viewModel: viewModel)
                }
            } else if showCamera {
                CameraPreview(showCamera: showCamera)
            } else if showLyrics {
                LyricsPanelView(viewModel: viewModel)
            } else {
                AmbientOnlyPane(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    @State private var isDragging = false
    @State private var dragValue = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: viewModel.spotifyState.isPlaying ? 0.08 : nil)) { timeline in
            let duration = max(1, viewModel.spotifyState.duration)
            let current = viewModel.playbackTime(at: timeline.date)

            VStack(spacing: 2) {
                Slider(
                    value: Binding(
                        get: {
                            isDragging ? dragValue : min(current, duration)
                        },
                        set: { newValue in
                            dragValue = newValue
                        }
                    ),
                    in: 0...duration,
                    onEditingChanged: { editing in
                        isDragging = editing
                        if editing {
                            dragValue = current
                        } else {
                            viewModel.seek(to: dragValue)
                        }
                    }
                )
                .tint(Color(nsColor: viewModel.accentColor))
                .controlSize(.small)

                HStack {
                    Text(formatTime(isDragging ? dragValue : current))
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
                        .lineLimit(3)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: 64, alignment: .center)
                        .contentTransition(.opacity)
                        .id(line.id)
                } else {
                    Text(line.text)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.32))
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity, minHeight: 18, maxHeight: 18, alignment: .center)
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
