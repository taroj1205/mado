import ApplicationServices
import AVFoundation

struct SystemPermissionProbe: PermissionProbe {
    static func flag(_ granted: Bool) -> PermissionStatus {
        granted ? .granted : .denied
    }

    static func media(_ status: AVAuthorizationStatus) -> PermissionStatus {
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
            Self.media(AVCaptureDevice.authorizationStatus(for: .audio))

        case .camera:
            Self.media(AVCaptureDevice.authorizationStatus(for: .video))

        case .calendars, .location:
            .unsupported
        }
    }

    func request(_ permission: Permission) async {
        switch permission {
        case .accessibility:
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)

        case .inputMonitoring:
            _ = CGRequestListenEventAccess()

        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()

        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)

        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)

        case .calendars, .location:
            break
        }
    }
}
