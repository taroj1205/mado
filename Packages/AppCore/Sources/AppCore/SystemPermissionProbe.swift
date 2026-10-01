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
}
