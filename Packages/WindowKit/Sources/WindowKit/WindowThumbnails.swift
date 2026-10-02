public import CoreGraphics
import Darwin
import ScreenCaptureKit

public enum WindowThumbnails {
    private typealias Connection = @convention(c) () -> Int32
    private typealias ServerCapture =
        @convention(c) (Int32, UnsafeMutablePointer<CGWindowID>, UInt32, UInt32) ->
        Unmanaged<CFArray>?

    private static let searchAllImages = -2
    private static let ignoreGlobalClipShape: UInt32 = 0x800
    private static let bestResolution: UInt32 = 0x100
    private static let bitsPerComponent = 8

    private static let serverImage: (@Sendable (CGWindowID) -> CGImage?)? = {
        let images = unsafe UnsafeMutableRawPointer(bitPattern: searchAllImages)
        guard let connect = unsafe dlsym(images, "CGSMainConnectionID"),
            let copy = unsafe dlsym(images, "CGSHWCaptureWindowList")
        else { return nil }
        let connection = unsafe unsafeBitCast(connect, to: Connection.self)()
        let capture = unsafe unsafeBitCast(copy, to: ServerCapture.self)
        let options = ignoreGlobalClipShape | bestResolution
        return { number in
            var number = number
            let list = unsafe capture(connection, &number, 1, options)?.takeRetainedValue()
            return (list as? [CGImage])?.first
        }
    }()

    public static var isAllowed: Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestAccess() {
        _ = CGRequestScreenCaptureAccess()
    }

    public static func capture(
        _ numbers: [CGWindowID], fitting box: CGSize, each: (CGWindowID, CGImage) -> Void
    ) async {
        guard isAllowed else { return }
        var missed: [CGWindowID] = []
        for number in numbers {
            guard !Task.isCancelled else { return }
            if let image = serverImage?(number).flatMap({ scaled($0, fitting: box) }) {
                each(number, image)
            } else {
                missed.append(number)
            }
            await Task.yield()
        }
        guard !missed.isEmpty,
            let content = try? await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true)
        else { return }
        for window in content.windows where missed.contains(window.windowID) {
            guard !Task.isCancelled else { return }
            if let image = await image(of: window, fitting: box) {
                each(window.windowID, image)
            }
        }
    }

    static func scaled(_ image: CGImage, fitting box: CGSize) -> CGImage? {
        let size = size(of: CGSize(width: image.width, height: image.height), fitting: box)
        guard size != .zero,
            let context = unsafe CGContext(
                data: nil, width: Int(size.width), height: Int(size.height),
                bitsPerComponent: bitsPerComponent,
                bytesPerRow: 0, space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                    | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
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
