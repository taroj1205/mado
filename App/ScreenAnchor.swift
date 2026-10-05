import AppKit
import WindowKit

@MainActor
enum ScreenAnchor {
    static func find(_ quartz: CGRect?) -> (rect: NSRect, screen: NSScreen?) {
        let primary = NSScreen.screens.first?.frame ?? .zero
        let anchor =
            quartz.map { ScreenGeometry.appKitRect(fromQuartz: $0, primary: primary) }
            ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen =
            NSScreen.screens.first { $0.frame.intersects(anchor.insetBy(dx: -1, dy: -1)) }
            ?? NSScreen.main
        return (anchor, screen)
    }
}
