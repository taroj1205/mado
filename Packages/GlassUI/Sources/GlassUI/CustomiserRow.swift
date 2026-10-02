import AppKit

final class CustomiserRow: NSView {
    private final class Grip: NSView {
        private static let across: CGFloat = 1.75
        private static let down: CGFloat = 3.5
        private static let radius: CGFloat = 0.875

        override func draw(_: NSRect) {
            NSColor.secondaryLabelColor.setFill()
            for column in [-Self.across, Self.across] {
                for row in [-Self.down, 0, Self.down] {
                    let centre = NSRect(
                        x: bounds.midX + column, y: bounds.midY + row, width: 0, height: 0)
                    NSBezierPath(ovalIn: centre.insetBy(dx: -Self.radius, dy: -Self.radius)).fill()
                }
            }
        }
    }

    static let height: CGFloat = 38
    private static let leading: CGFloat = 4
    private static let trailing: CGFloat = 8
    private static let gap: CGFloat = 10
    private static let grip: CGFloat = 14
    private static let tileSize: CGFloat = 26
    private static let tileRadius: CGFloat = 7
    private static let symbolSize: CGFloat = 15
    private static let nameSize: CGFloat = 13.5
    private static let readingSize: CGFloat = 12.5

    let toggle = NSSwitch()
    let name = NSTextField(labelWithString: "")
    let reading = NSTextField(labelWithString: "")
    private let icon = NSImageView()
    private let handle = Grip()
    var onToggle: ((Bool) -> Void)?

    init(shown: Bool) {
        super.init(frame: .zero)
        handle.isHidden = !shown
        toggle.controlSize = .small
        toggle.refusesFirstResponder = true
        toggle.state = shown ? .on : .off
        toggle.target = self
        toggle.action = #selector(toggled)
        icon.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .regular)
        icon.contentTintColor = .labelColor
        name.font = .systemFont(ofSize: Self.nameSize, weight: .medium)
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        reading.font = .monospacedDigitSystemFont(ofSize: Self.readingSize, weight: .regular)
        reading.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [handle, makeTile(), name, reading, toggle])
        stack.spacing = Self.gap
        stack.distribution = .fill
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.leading, bottom: 0, right: Self.trailing)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            handle.widthAnchor.constraint(equalToConstant: Self.grip),
            handle.heightAnchor.constraint(equalToConstant: Self.grip),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ pill: StatusBar.Pill) {
        icon.image = NSImage(systemSymbolName: pill.symbol, accessibilityDescription: nil)
        name.stringValue = pill.name
        reading.stringValue = pill.reading
        toggle.setAccessibilityLabel("Show \(pill.name) in the status bar")
    }

    private func makeTile() -> NSView {
        let tile = NSBox()
        tile.boxType = .custom
        tile.borderWidth = 0
        tile.cornerRadius = Self.tileRadius
        tile.fillColor = FloatingCapsule.keycapFill
        tile.contentViewMargins = .zero
        icon.translatesAutoresizingMaskIntoConstraints = false
        tile.addSubview(icon)
        tile.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Self.tileSize),
            icon.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: tile.centerYAnchor),
        ])
        return tile
    }

    @objc
    private func toggled() {
        onToggle?(toggle.state == .on)
    }
}
