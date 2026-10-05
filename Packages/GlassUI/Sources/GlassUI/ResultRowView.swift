import AppKit

final class ResultRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("row")
    static let radius: CGFloat = 12
    static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .systemFill : .secondarySystemFill
    }

    var radius = ResultRowView.radius

    var trailingInset: CGFloat = 0 {
        didSet {
            needsLayout = true
            needsDisplay = true
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        for view in subviews {
            view.frame.size.width = bounds.width - trailingInset
        }
    }

    override func drawSelection(in _: NSRect) {
        Self.fill.setFill()
        let row = NSRect(
            x: 0, y: 0, width: bounds.width - trailingInset,
            height: bounds.height - ResultList.rowGap)
        NSBezierPath(roundedRect: row, xRadius: radius, yRadius: radius).fill()
    }
}
