import AppKit

@MainActor
protocol MenuBarPanel: NSView {
    var onResize: ((NSSize) -> Void)? { get set }
}
