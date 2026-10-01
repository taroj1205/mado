import AppKit

final class HotkeyFieldBox: NSView {
    private typealias Style = HotkeyRecorderStyle

    private let border: NSColor
    private let dashed: Bool

    init(border: NSColor, dashed: Bool, views: [NSView]) {
        self.border = border
        self.dashed = dashed
        super.init(frame: .zero)
        let row = NSStackView(views: views)
        row.spacing = Style.keySpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Style.fieldHeight),
            row.centerXAnchor.constraint(equalTo: centerXAnchor),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        Style.fieldFill.setFill()
        let radius = Style.fieldRadius
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        let half = Style.fieldBorderInset
        let outline = NSBezierPath(
            roundedRect: bounds.insetBy(dx: half, dy: half),
            xRadius: radius - half, yRadius: radius - half)
        outline.lineWidth = Style.fieldBorderWidth
        if dashed {
            unsafe outline.setLineDash(
                Style.dashPattern, count: Style.dashPattern.count, phase: Style.dashPhase)
        }
        border.setStroke()
        outline.stroke()
    }
}
