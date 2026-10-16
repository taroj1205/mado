public import AVFoundation
import Foundation

@MainActor
public final class CameraSession {
    public enum Failure: Error, Equatable, Sendable {
        case noCamera
        case unreadable
    }

    public struct Opened: Equatable, Sendable {
        public let device: CameraDevice
        public let size: CGSize
    }

    public var onDevicesChanged: (@MainActor () -> Void)?
    public var onFailed: (@MainActor () -> Void)?

    private let engine: CameraEngine
    private var observers: [any NSObjectProtocol] = []

    public var captureSession: AVCaptureSession {
        engine.session
    }

    public init() {
        engine = CameraEngine()
    }

    public static func devices() -> [CameraDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified
        )
        .devices
        .filter { !$0.isSuspended }
        .map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    public func start(preferring saved: String?) async -> Result<Opened, Failure> {
        watch()
        let preferred = AVCaptureDevice.systemPreferredCamera?.uniqueID
        var failure = Failure.noCamera
        let devices = CameraDevice.ordered(
            from: Self.devices(), saved: saved, preferred: preferred)
        for device in devices {
            switch await engine.open(device.id) {
            case .success(let size): return .success(Opened(device: device, size: size))
            case .failure(let reason): failure = reason
            }
        }
        return .failure(failure)
    }

    public func takePhoto(mirrored: Bool) async -> Data? {
        await engine.capture(mirrored: mirrored)
    }

    public func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        engine.close()
    }

    private func watch() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        let changed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.onDevicesChanged?() }
        }
        let failed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.onFailed?() }
        }
        observers = [
            AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification,
        ]
        .map { name in center.addObserver(forName: name, object: nil, queue: .main, using: changed)
        }
        observers.append(
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification, object: engine.session,
                queue: .main, using: failed))
    }
}
