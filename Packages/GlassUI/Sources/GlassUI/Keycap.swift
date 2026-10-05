public import AppKit

public final class Keycap: NSBox {
    private static let inset: CGFloat = 10
    private static let fontSize: CGFloat = 11

    let name: NSTextField

    public init(_ key: String, radius: CGFloat, size: CGFloat) {
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
            heightAnchor.constraint(equalToConstant: size),
            widthAnchor.constraint(greaterThanOrEqualToConstant: size),
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
