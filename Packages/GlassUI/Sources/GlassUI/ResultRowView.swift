import AppKit

final class ResultRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("row")
    static let radius: CGFloat = 12
    static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .systemFill : .secondarySystemFill
    }

    var radius = ResultRowView.radius

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
        let row = NSRect(
            x: 0, y: 0, width: bounds.width, height: bounds.height - ResultList.rowGap)
        NSBezierPath(roundedRect: row, xRadius: radius, yRadius: radius).fill()
    }
}
