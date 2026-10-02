import AppKit

final class Keycap: NSBox {
    private static let size: CGFloat = 20
    private static let inset: CGFloat = 10
    private static let fontSize: CGFloat = 11

    let name: NSTextField

    init(_ key: String, radius: CGFloat) {
        name = NSTextField(labelWithString: key)
        super.init(frame: .zero)
        boxType = .custom
        borderWidth = 0
        cornerRadius = radius
        fillColor = FloatingCapsule.keycapFill
        contentViewMargins = .zero
        name.font = .systemFont(ofSize: Self.fontSize, weight: .medium)
        name.textColor = .secondaryLabelColor
        name.translatesAutoresizingMaskIntoConstraints = false
        addSubview(name)
        let compact = widthAnchor.constraint(equalTo: name.widthAnchor, constant: Self.inset)
        compact.priority = .defaultHigh
        NSLayoutConstraint.activate([
            compact,
            heightAnchor.constraint(equalToConstant: Self.size),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Self.size),
            widthAnchor.constraint(greaterThanOrEqualTo: name.widthAnchor, constant: Self.inset),
            name.centerXAnchor.constraint(equalTo: centerXAnchor),
            name.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
