import AVFoundation
import SwiftUI

@MainActor
final class CameraManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var authorizationDenied = false

    let session = AVCaptureSession()
    private var isConfigured = false

    func start() {
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

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            authorizationDenied = true
            return
        }

        session.addInput(input)
        isConfigured = true
    }

    private func startSession() {
        guard isConfigured, !session.isRunning else {
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
    @StateObject private var manager = CameraManager()

    var body: some View {
        ZStack {
            CameraPreviewLayerView(session: manager.session)
                .opacity(manager.authorizationDenied ? 0 : 1)

            if manager.authorizationDenied {
                Image(systemName: "video.slash")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
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
