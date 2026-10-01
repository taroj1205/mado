import AppKit

final class ResultRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("row")
    private static let radius: CGFloat = 10
    static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .systemFill : .secondarySystemFill
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func drawSelection(in _: NSRect) {
        Self.fill.setFill()
        let row = NSRect(x: 0, y: 0, width: bounds.width, height: ResultList.rowHeight)
        NSBezierPath(roundedRect: row, xRadius: Self.radius, yRadius: Self.radius).fill()
    }
}
