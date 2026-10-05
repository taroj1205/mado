import AppKit
import WindowKit

@MainActor
enum CaretAnchor {
    static func find(_ caret: CGRect?) -> (rect: NSRect, screen: NSScreen?) {
        let primary = NSScreen.screens.first?.frame ?? .zero
        let anchor =
            caret.map { ScreenGeometry.appKitRect(fromQuartz: $0, primary: primary) }
            ?? NSRect(origin: NSEvent.mouseLocation, size: .zero)
        let screen =
            NSScreen.screens.first { $0.frame.intersects(anchor.insetBy(dx: -1, dy: -1)) }
            ?? NSScreen.main
        return (anchor, screen)
    }
}
