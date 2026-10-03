import ApplicationServices
import AVFoundation

struct SystemPermissionProbe: PermissionProbe {
    static func flag(_ granted: Bool) -> PermissionStatus {
        granted ? .granted : .denied
    }

    static func microphone(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: .granted

        case .notDetermined: .notDetermined

        case .denied, .restricted: .denied

        @unknown default: .denied
        }
    }

    func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .accessibility:
            Self.flag(AXIsProcessTrusted())

        case .inputMonitoring:
            Self.flag(CGPreflightListenEventAccess())

        case .screenRecording:
            Self.flag(CGPreflightScreenCaptureAccess())

        case .microphone:
            Self.microphone(AVCaptureDevice.authorizationStatus(for: .audio))

        case .calendars:
            .unsupported
        }
    }

    func request(_ permission: Permission) async -> PermissionStatus {
        switch permission {
        case .accessibility:
            Self.flag(
                AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary))

        case .inputMonitoring:
            Self.flag(CGRequestListenEventAccess())

        case .screenRecording:
            Self.flag(CGRequestScreenCaptureAccess())

        case .microphone:
            Self.flag(await AVCaptureDevice.requestAccess(for: .audio))

        case .calendars:
            .unsupported
        }
    }
}
