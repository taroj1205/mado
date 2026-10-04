import AppKit

final class HotKeyField: NSView {
    enum Style {
        case waiting
        case captured
        case conflict
    }

    private static let height: CGFloat = 52
    private static let radius: CGFloat = 12
    private static let lineWidth: CGFloat = 1.5
    private static let half: CGFloat = 0.5
    private static let dash: [CGFloat] = [dashLength, dashGap]
    private static let dashLength: CGFloat = 4
    private static let dashGap: CGFloat = 3
    private static let gap: CGFloat = 5
    private static let keycapSize: CGFloat = 30
    private static let keycapInset: CGFloat = 10
    private static let keycapRadius: CGFloat = 5
    private static let keySize: CGFloat = 15
    private static let dotSize: CGFloat = 8
    private static let promptSize: CGFloat = 13
    private static let suffixSize: CGFloat = 12
    private static let fillAlpha = (dark: 0.25, light: 0.05)
    private static let borderAlpha = 0.18
    private static let keycapAlpha = (dark: 0.16, light: 0.08)
    private static let fill = adaptive(
        dark: .black.withAlphaComponent(fillAlpha.dark),
        light: .black.withAlphaComponent(fillAlpha.light))
    private static let dashedBorder = adaptive(
        dark: .white.withAlphaComponent(borderAlpha), light: .black.withAlphaComponent(borderAlpha))
    private static let keycapFill = adaptive(
        dark: .white.withAlphaComponent(keycapAlpha.dark),
        light: .black.withAlphaComponent(keycapAlpha.light))

    var onPress: (() -> Void)?

    private let content = NSStackView()
    private var style = Style.waiting {
        didSet { needsDisplay = true }
    }

    convenience init() {
        self.init(height: Self.height)
    }

    init(height: CGFloat) {
        super.init(frame: .zero)
        content.spacing = Self.gap
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: height),
            content.centerXAnchor.constraint(equalTo: centerXAnchor),
            content.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Hotkey")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    private static func label(_ text: String, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func keycap(_ text: String) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderWidth = 0
        box.cornerRadius = keycapRadius
        box.fillColor = keycapFill
        let name = NSTextField(labelWithString: text)
        name.font = .systemFont(ofSize: keySize, weight: .medium)
        name.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(name)
        let snug = box.widthAnchor.constraint(equalTo: name.widthAnchor, constant: keycapInset)
        snug.priority = .defaultHigh
        NSLayoutConstraint.activate([
            snug,
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: keycapSize),
            box.widthAnchor.constraint(
                greaterThanOrEqualTo: name.widthAnchor, constant: keycapInset),
            box.heightAnchor.constraint(equalToConstant: keycapSize),
            name.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            name.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    func showPrompt(_ prompt: String) {
        style = .waiting
        let dot = NSBox()
        dot.boxType = .custom
        dot.borderWidth = 0
        dot.cornerRadius = Self.dotSize * Self.half
        dot.fillColor = .systemRed
        dot.widthAnchor.constraint(equalToConstant: Self.dotSize).isActive = true
        dot.heightAnchor.constraint(equalToConstant: Self.dotSize).isActive = true
        content.setViews([dot, Self.label(prompt, size: Self.promptSize)], in: .center)
        setAccessibilityValue(prompt)
    }

    func show(_ keycaps: [String], suffix: String?, style: Style) {
        self.style = style
        let suffixLabel = suffix.map { Self.label($0, size: Self.suffixSize) }
        content.setViews(keycaps.map(Self.keycap) + [suffixLabel].compactMap(\.self), in: .center)
        setAccessibilityValue(
            HotKeyLabel.spoken(text: (keycaps + [suffix].compactMap(\.self)).joined(separator: " "))
        )
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }

    override func draw(_: NSRect) {
        let inset = Self.lineWidth * Self.half
        let path = NSBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: Self.radius,
            yRadius: Self.radius)
        Self.fill.setFill()
        path.fill()
        path.lineWidth = Self.lineWidth
        switch style {
        case .waiting:
            Self.dashedBorder.setStroke()
            unsafe path.setLineDash(Self.dash, count: Self.dash.count, phase: 0)

        case .captured:
            NSColor.controlAccentColor.setStroke()

        case .conflict:
            NSColor.systemOrange.setStroke()
        }
        path.stroke()
    }
}
