import AppCore
import AVFoundation

@MainActor
final class CameraFeed {
    enum State: Equatable {
        case idle
        case starting
        case needsPermission
        case denied
        case live
        case noCamera
        case failed
    }

    var onChange: (() -> Void)?
    private(set) var state = State.idle {
        didSet {
            if state != oldValue { onChange?() }
        }
    }

    private(set) var mirrored = true
    private let camera: CameraSession
    private let settings: () -> CameraSettings
    private let permissions = PermissionManager()
    private var holding = false
    private var run = 0

    var session: AVCaptureSession {
        camera.captureSession
    }

    init(camera: CameraSession, settings: @escaping () -> CameraSettings) {
        self.camera = camera
        self.settings = settings
    }

    func start() {
        guard !holding else { return }
        permissions.refresh()
        switch permissions.status(for: .camera) {
        case .granted: open()
        case .notDetermined: state = .needsPermission
        default: state = .denied
        }
    }

    func allow() {
        Task {
            _ = await permissions.request(.camera)
            start()
        }
    }

    func stop() {
        run += 1
        if holding {
            holding = false
            camera.release()
        }
        state = .idle
    }

    private func open() {
        holding = true
        camera.retain()
        run += 1
        let mine = run
        let saved = settings()
        mirrored = saved.mirrored
        state = .starting
        Task {
            let result = await camera.start(preferring: saved.deviceID)
            guard run == mine else { return }
            switch result {
            case .success: state = .live
            case .failure(.noCamera): state = .noCamera
            case .failure(.unreadable): state = .failed
            }
        }
    }
}
