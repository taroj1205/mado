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
    private var users = 0
    private var opened: Opened?

    public var isInUse: Bool {
        users > 0
    }

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
        let devices = CameraDevice.ordered(
            from: Self.devices(), saved: saved, preferred: preferred)
        if let opened, opened.device == devices.first { return .success(opened) }
        var failure = Failure.noCamera
        for device in devices {
            switch await engine.open(device.id) {
            case .success(let size):
                let result = Opened(device: device, size: size)
                opened = isInUse ? result : nil
                return .success(result)

            case .failure(let reason):
                failure = reason
            }
        }
        opened = nil
        return .failure(failure)
    }

    public func retain() {
        users += 1
    }

    public func release() {
        users = max(users - 1, 0)
        guard users == 0 else { return }
        opened = nil
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
            MainActor.assumeIsolated {
                self?.opened = nil
                self?.onFailed?()
            }
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
