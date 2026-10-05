import AppCore
import AppKit

enum ScreenCaptureAccess {
    struct Denied: Error {}

    @MainActor
    static func require() throws {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            NSWorkspace.shared.open(PermissionManager.settingsURL(for: .screenRecording))
            throw Denied()
        }
    }
}
