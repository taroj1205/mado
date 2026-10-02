import AppKit

final class WidgetTile: NSView {
    private typealias Look = (fill: NSColor, edge: NSColor)

    static let radius: CGFloat = 16
    private static let horizontal: CGFloat = 12
    private static let vertical: CGFloat = 10
    private static let valueSize: CGFloat = 22
    private static let valueKern: CGFloat = -0.4
    private static let detailSize: CGFloat = 11.5
    private static let iconSize: CGFloat = 13
    private static let iconGap: CGFloat = 4
    private static let meterGap: CGFloat = 8
    private static let fillAlpha = (dark: 0.055, light: 0.55)
    private static let edgeAlpha = (dark: 0.07, light: 0.06)
    private static let selectedFillAlpha = (dark: 0.13, light: 0.065)
    private static let selectedEdgeAlpha = (dark: 0.26, light: 0.16)
    private static let floatingSelectedAlpha = (dark: 0.34, light: 0.80)
    private static let floatingSelectedTint = (red: 0.55, green: 0.55, blue: 0.63)
    private static let fill = tone(.white, .white, fillAlpha)
    private static let edge = tone(.white, .black, edgeAlpha)
    private static let selectedFill = tone(.white, .black, selectedFillAlpha)
    private static let selectedEdge = tone(.white, .black, selectedEdgeAlpha)
    private static let floatingSelectedFill = tone(
        NSColor(
            srgbRed: floatingSelectedTint.red, green: floatingSelectedTint.green,
            blue: floatingSelectedTint.blue, alpha: 1),
        .white, floatingSelectedAlpha)
    private static let inlineLooks: (resting: Look, picked: Look) = (
        (fill, edge), (selectedFill, selectedEdge)
    )
    private static let floatingLooks: (resting: Look, picked: Look) = (
        (.clear, .clear), (floatingSelectedFill, selectedEdge)
    )

    let value = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let icon = NSImageView()
    let meters = NSStackView()
    private let box = NSBox()
    private let looks: (resting: Look, picked: Look)
    var onPress: (() -> Void)?

    var selected = false {
        didSet { paint() }
    }

    init(floating: Bool) {
        looks = floating ? Self.floatingLooks : Self.inlineLooks
        super.init(frame: .zero)
        box.boxType = .custom
        box.cornerRadius = Self.radius
        box.borderWidth = 1
        paint()
        box.autoresizingMask = [.width, .height]
        addSubview(box)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        for label in [value, detail] {
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
        }
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        meters.orientation = .vertical
        meters.spacing = Self.meterGap
        meters.translatesAutoresizingMaskIntoConstraints = false
        addSubview(meters)
        NSLayoutConstraint.activate([
            meters.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            meters.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            meters.centerYAnchor.constraint(equalTo: centerYAnchor),
            value.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            value.trailingAnchor.constraint(
                lessThanOrEqualTo: icon.leadingAnchor, constant: -Self.iconGap),
            icon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            icon.centerYAnchor.constraint(equalTo: value.centerYAnchor),
            value.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
            detail.leadingAnchor.constraint(equalTo: value.leadingAnchor),
            detail.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.horizontal),
            detail.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func tone(
        _ dark: NSColor, _ light: NSColor, _ alpha: (dark: Double, light: Double)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark.withAlphaComponent(alpha.dark) : light.withAlphaComponent(alpha.light)
        }
    }

    private func paint() {
        let look = selected ? looks.picked : looks.resting
        box.fillColor = look.fill
        box.borderColor = look.edge
        setAccessibilitySelected(selected)
    }

    func show(_ widget: WidgetGrid.Widget) {
        value.attributedStringValue = NSAttributedString(
            string: widget.value,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: Self.valueSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .kern: Self.valueKern,
            ])
        detail.stringValue = widget.detail
        icon.image = widget.symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        value.isHidden = !widget.meters.isEmpty
        detail.isHidden = !widget.meters.isEmpty
        if meters.arrangedSubviews.count != widget.meters.count {
            meters.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for _ in widget.meters {
                let meter = WidgetMeter()
                meters.addArrangedSubview(meter)
                meter.widthAnchor.constraint(equalTo: meters.widthAnchor).isActive = true
            }
        }
        for (view, meter) in zip(meters.arrangedSubviews, widget.meters) {
            (view as? WidgetMeter)?.show(meter)
        }
        setAccessibilityLabel(widget.spoken)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with _: NSEvent) {
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}
