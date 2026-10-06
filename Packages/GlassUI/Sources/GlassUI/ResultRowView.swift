import AppKit

final class ResultRowView: NSTableRowView {
    static let id = NSUserInterfaceItemIdentifier("row")
    static let radius: CGFloat = 12
    static let fill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .systemFill : .secondarySystemFill
    }

    private static let checkedAlpha: CGFloat = 0.16
    static let checkedFill = NSColor.controlAccentColor.withAlphaComponent(checkedAlpha)

    var radius = ResultRowView.radius {
        didSet { hover.radius = radius }
    }

    private let hover = HoverFill(radius: ResultRowView.radius)

    var isChecked = false {
        didSet { needsDisplay = true }
    }

    var trailingInset: CGFloat = 0 {
        didSet {
            needsLayout = true
            needsDisplay = true
        }
    }

    private var rowRect: NSRect {
        NSRect(
            x: 0, y: 0, width: bounds.width - trailingInset,
            height: bounds.height - ResultList.rowGap)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        addSubview(hover)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        for view in subviews where view !== hover {
            view.frame.size.width = bounds.width - trailingInset
        }
        hover.frame = rowRect
    }

    override func drawBackground(in dirtyRect: NSRect) {
        super.drawBackground(in: dirtyRect)
        if isChecked {
            Self.checkedFill.setFill()
            fillRow()
        }
    }

    override func drawSelection(in _: NSRect) {
        Self.fill.setFill()
        fillRow()
    }

    private func fillRow() {
        NSBezierPath(roundedRect: rowRect, xRadius: radius, yRadius: radius).fill()
    }
}
