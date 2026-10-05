public import CoreGraphics
import Foundation
import ScreenCaptureKit

public enum ScreenSnapshot {
    public static func capture(
        displays wanted: Set<CGDirectDisplayID>
    ) async throws -> [CGDirectDisplayID: CGImage] {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: true)
        let own = content.applications.filter { application in
            application.processID == ProcessInfo.processInfo.processIdentifier
        }
        var images: [CGDirectDisplayID: CGImage] = [:]
        for display in content.displays where wanted.contains(display.displayID) {
            let filter = SCContentFilter(
                display: display, excludingApplications: own, exceptingWindows: [])
            let scale = CGFloat(filter.pointPixelScale)
            let configuration = SCStreamConfiguration()
            configuration.width = Int((filter.contentRect.width * scale).rounded())
            configuration.height = Int((filter.contentRect.height * scale).rounded())
            unsafe configuration.colorSpaceName = CGColorSpace.sRGB
            configuration.showsCursor = false
            images[display.displayID] = try await SCScreenshotManager.captureImage(
                contentFilter: filter, configuration: configuration)
        }
        return images
    }
}
