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
        let preferred = AVCaptureDevice.systemPreferredCamera?.uniqueID
        guard
            let device = CameraDevice.choose(
                from: Self.devices(), saved: saved, preferred: preferred)
        else {
            opened = nil
            return .failure(.noCamera)
        }
        if let opened, opened.device == device { return .success(opened) }
        watch()
        let result = await engine.open(device.id).map { Opened(device: device, size: $0) }
        opened = isInUse ? try? result.get() : nil
        return result
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
        let changed: @Sendable (Notification) -> Void = { [weak self] _ in
            MainActor.assumeIsolated { self?.onDevicesChanged?() }
        }
        observers = [
            AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification,
        ]
        .map { name in
            NotificationCenter.default.addObserver(
                forName: name, object: nil, queue: .main, using: changed)
        }
    }
}
