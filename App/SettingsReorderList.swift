import AppKit

@MainActor
final class SettingsReorderList: NSView, NSDraggingSource {
    private static let type = NSPasteboard.PasteboardType("com.taroj1205.mado.settings-row")
    private static let threshold: CGFloat = 4
    private static let lineHeight: CGFloat = 2
    private static let halfLine: CGFloat = 1

    private let rows: [NSView]
    private let keys: [String]
    private let onMove: (String, String?) -> Void
    private let line = NSBox()
    private var press: (index: Int, point: NSPoint)?

    override var mouseDownCanMoveWindow: Bool { false }

    init(
        box: NSView, rows: [NSView], keys: [String], onMove: @escaping (String, String?) -> Void
    ) {
        self.rows = rows
        self.keys = keys
        self.onMove = onMove
        super.init(frame: .zero)
        box.translatesAutoresizingMaskIntoConstraints = false
        addSubview(box)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: topAnchor),
            box.bottomAnchor.constraint(equalTo: bottomAnchor),
            box.leadingAnchor.constraint(equalTo: leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        line.boxType = .custom
        line.titlePosition = .noTitle
        line.borderWidth = 0
        line.fillColor = .controlAccentColor
        line.isHidden = true
        addSubview(line)
        registerForDraggedTypes([Self.type])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func image(of row: NSView) -> NSImage {
        let size = row.bounds.size
        guard let rep = row.bitmapImageRepForCachingDisplay(in: row.bounds) else {
            return NSImage(size: size)
        }
        row.cacheDisplay(in: row.bounds, to: rep)
        return NSImage(size: size, flipped: false) { rect in
            row.effectiveAppearance.performAsCurrentDrawingAppearance {
                NSColor.windowBackgroundColor.setFill()
                rect.fill()
            }
            return rep.draw(in: rect)
        }
    }

    private func frame(of row: NSView) -> NSRect {
        row.convert(row.bounds, to: self)
    }

    private func slot(at point: NSPoint) -> Int {
        rows.count { frame(of: $0).midY > point.y }
    }

    private func show(slot: Int) {
        let edge = slot == 0 ? frame(of: rows[0]).maxY : frame(of: rows[slot - 1]).minY
        line.frame = NSRect(
            x: 0, y: edge - Self.halfLine, width: bounds.width, height: Self.lineHeight)
        line.isHidden = false
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        press = rows.firstIndex { frame(of: $0).contains(point) }.map { ($0, point) }
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let press, hypot(point.x - press.point.x, point.y - press.point.y) >= Self.threshold
        else { return }
        self.press = nil
        let item = NSPasteboardItem()
        item.setString(keys[press.index], forType: Self.type)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let row = rows[press.index]
        dragging.setDraggingFrame(frame(of: row), contents: Self.image(of: row))
        beginDraggingSession(with: [dragging], event: event, source: self)
    }

    override func mouseUp(with _: NSEvent) {
        press = nil
    }

    func draggingSession(
        _: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation _: NSDragOperation) {
        line.isHidden = true
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hover(sender)
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        line.isHidden = true
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        line.isHidden = true
        guard (sender.draggingSource as? Self) === self,
            let key = sender.draggingPasteboard.string(forType: Self.type)
        else { return false }
        let index = slot(at: convert(sender.draggingLocation, from: nil))
        let target = keys.indices.contains(index) ? keys[index] : nil
        Task { @MainActor [onMove] in onMove(key, target) }
        return true
    }

    private func hover(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard (sender.draggingSource as? Self) === self else { return [] }
        if let event = NSApp.currentEvent {
            _ = autoscroll(with: event)
        }
        show(slot: slot(at: convert(sender.draggingLocation, from: nil)))
        return .move
    }
}
