import AppKit

final class AllowCapsule: NSView {
    private static let height: CGFloat = 24
    private static let radius: CGFloat = 12
    private static let padding: CGFloat = 12
    private static let textSize: CGFloat = 13

    let label = NSTextField(labelWithString: "Allow")

    init() {
        super.init(frame: .zero)
        label.font = .systemFont(ofSize: Self.textSize, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.padding),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func draw(_: NSRect) {
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius).fill()
    }
}
