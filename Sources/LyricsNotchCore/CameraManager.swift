import AVFoundation
import SwiftUI

@MainActor
final class CameraManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var authorizationDenied = false
    @Published private(set) var setupFailed = false

    let session = AVCaptureSession()
    private var isConfigured = false

    func start() {
        setupFailed = false

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureIfNeeded()
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.authorizationDenied = !granted
                    if granted {
                        self.configureIfNeeded()
                        self.startSession()
                    }
                }
            }
        case .denied, .restricted:
            authorizationDenied = true
            stop()
        @unknown default:
            authorizationDenied = true
            stop()
        }
    }

    func stop() {
        guard session.isRunning else {
            isRunning = false
            return
        }

        let session = session
        Task.detached(priority: .utility) {
            session.stopRunning()
            await MainActor.run {
                self.isRunning = false
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .medium

        defer {
            session.commitConfiguration()
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            setupFailed = true
            return
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            setupFailed = true
            return
        }

        guard session.canAddInput(input) else {
            setupFailed = true
            return
        }

        session.addInput(input)
        isConfigured = true
    }

    private func startSession() {
        guard isConfigured, !setupFailed, !session.isRunning else {
            isRunning = session.isRunning
            return
        }

        let session = session
        Task.detached(priority: .userInitiated) {
            session.startRunning()
            await MainActor.run {
                self.isRunning = true
            }
        }
    }
}

struct CameraPreview: View {
    let showCamera: Bool
    @ObservedObject var manager: CameraManager

    var body: some View {
        ZStack {
            CameraPreviewLayerView(session: manager.session)
                .opacity(isUnavailable ? 0 : 1)

            if isUnavailable {
                VStack(spacing: 7) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 20, weight: .semibold))

                    Text(manager.authorizationDenied ? "Camera blocked" : "No camera")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.55))
            } else if !manager.isRunning {
                VStack(spacing: 7) {
                    Image(systemName: "video")
                        .font(.system(size: 20, weight: .semibold))

                    Text("Starting camera")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.44))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        }
        .background(.black)
        .onAppear {
            if showCamera {
                manager.start()
            }
        }
        .onChange(of: showCamera) { _, enabled in
            enabled ? manager.start() : manager.stop()
        }
        .onDisappear {
            manager.stop()
        }
    }

    private var isUnavailable: Bool {
        manager.authorizationDenied || manager.setupFailed
    }
}

private struct CameraPreviewLayerView: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.previewLayer.session = session
    }
}

private final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        layer?.masksToBounds = true
        layer?.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}
