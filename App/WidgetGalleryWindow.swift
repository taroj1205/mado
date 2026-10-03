import AppCore
import AppKit
import GlassUI
import WindowKit

@MainActor
final class WidgetGalleryWindow: NSObject, NSToolbarDelegate, NSWindowDelegate {
    private static let width: CGFloat = 920
    private static let height: CGFloat = 640
    private static let radius: CGFloat = 26
    private static let filter = NSToolbarItem.Identifier("filter")

    private let modules: ModuleManager?
    private let gallery = WidgetGallery(cards: Widgets.gallery)
    private lazy var window = makeWindow()
    var onChange: (() -> Void)?
    var onClose: (() -> Void)?

    var isVisible: Bool { window.isVisible }

    init(modules: ModuleManager?) {
        self.modules = modules
        super.init()
        gallery.onAdd = { [weak self] id in self?.add(id) }
        gallery.onDone = { [weak self] in self?.window.close() }
    }

    func show() {
        refresh()
        if !window.isVisible {
            window.center()
        }
        present()
    }

    func show(over launcher: NSWindow, below top: CGFloat) {
        refresh()
        gallery.hintsDrag = true
        window.level = NSWindow.Level(launcher.level.rawValue + 1)
        if !window.isVisible, let screen = launcher.screen {
            let frame = ScreenGeometry.bottomFrame(
                of: window.frame.size, centeredOn: launcher.frame.midX, below: top,
                on: .init(frame: screen.frame, visibleFrame: screen.visibleFrame))
            window.setFrameOrigin(frame.origin)
        }
        NSRunningApplication.current.activate(
            from: NSWorkspace.shared.frontmostApplication ?? .current, options: [])
        present()
    }

    func refresh() {
        gallery.added = Widgets.added(in: modules)
    }

    func close() {
        window.close()
    }

    func windowWillClose(_: Notification) {
        onClose?()
    }

    func toolbarDefaultItemIdentifiers(_: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.flexibleSpace, Self.filter]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(
        _: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar _: Bool
    ) -> NSToolbarItem? {
        guard identifier == Self.filter else { return nil }
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.view = gallery.filter
        item.label = "Show"
        return item
    }

    private func add(_ id: String) {
        Widgets.edit(.add(id), in: modules)
        refresh()
        onChange?()
    }

    private func present() {
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)
    }

    private func makeWindow() -> NSWindow {
        let made = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: Self.height),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered, defer: true)
        made.title = "Add Widgets"
        made.titlebarAppearsTransparent = true
        let toolbar = NSToolbar(identifier: "widgetGallery")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        made.toolbar = toolbar
        made.toolbarStyle = .unified
        made.isReleasedWhenClosed = false
        made.delegate = self
        made.isOpaque = false
        made.backgroundColor = .clear
        let glass = GlassView(shape: .rounded(Self.radius), tint: SettingsWindowController.tint)
        glass.contentView = gallery
        made.contentView = glass
        return made
    }
}
