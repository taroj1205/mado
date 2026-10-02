public import CoreGraphics
import ScreenCaptureKit

public enum WindowThumbnails {
    public static var isAllowed: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestAccess() {
        _ = CGRequestScreenCaptureAccess()
    }

    public static func capture(
        _ numbers: [CGWindowID], fitting box: CGSize, each: (CGWindowID, CGImage) -> Void
    ) async {
        guard isAllowed,
            let content = try? await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true)
        else { return }
        for window in content.windows where numbers.contains(window.windowID) {
            guard !Task.isCancelled else { return }
            if let image = await image(of: window, fitting: box) {
                each(window.windowID, image)
            }
        }
    }

    static func size(of frame: CGSize, fitting box: CGSize) -> CGSize {
        guard frame.width > 0, frame.height > 0 else { return .zero }
        let scale = min(box.width / frame.width, box.height / frame.height)
        return CGSize(
            width: (frame.width * scale).rounded(), height: (frame.height * scale).rounded())
    }

    private static func image(of window: SCWindow, fitting box: CGSize) async -> CGImage? {
        let size = size(of: window.frame.size, fitting: box)
        guard size != .zero else { return nil }
        let configuration = SCStreamConfiguration()
        configuration.width = Int(size.width)
        configuration.height = Int(size.height)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        return try? await SCScreenshotManager.captureImage(
            contentFilter: SCContentFilter(desktopIndependentWindow: window),
            configuration: configuration)
    }
}
