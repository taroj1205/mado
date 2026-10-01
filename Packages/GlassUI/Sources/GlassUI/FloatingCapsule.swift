import AppKit

@MainActor
enum FloatingCapsule {
    static let height: CGFloat = 40
    private static let fontSize: CGFloat = 13
    private static let keycapSize: CGFloat = 20
    private static let keycapRadius: CGFloat = 10
    private static let keycapInset: CGFloat = 10
    private static let keycapFontSize: CGFloat = 11
    private static let keycapAlpha = (dark: 0.10, light: 0.07)
    private static let dividerHeight: CGFloat = 14
    static let keycapFill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(keycapAlpha.dark)
            : .black.withAlphaComponent(keycapAlpha.light)
    }

    static func make(_ stack: NSStackView, leading: CGFloat, trailing: CGFloat) -> GlassView {
        let glass = GlassView(shape: .capsule)
        glass.sheen.rimmed = true
        stack.edgeInsets = NSEdgeInsets(top: 0, left: leading, bottom: 0, right: trailing)
        stack.setHuggingPriority(.defaultHigh, for: .horizontal)
        glass.contentView = stack
        glass.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glass.heightAnchor.constraint(equalToConstant: height),
            stack.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            stack.topAnchor.constraint(equalTo: glass.topAnchor),
            stack.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        return glass
    }

    static func label(weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: fontSize, weight: weight)
        label.textColor = color
        return label
    }

    static func keycap(_ key: String) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = keycapRadius
        box.fillColor = keycapFill
        box.contentViewMargins = .zero
        let name = NSTextField(labelWithString: key)
        name.font = .systemFont(ofSize: keycapFontSize, weight: .medium)
        name.textColor = .secondaryLabelColor
        name.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(name)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: keycapSize),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: keycapSize),
            box.widthAnchor.constraint(
                greaterThanOrEqualTo: name.widthAnchor, constant: keycapInset),
            name.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            name.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    static func divider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        NSLayoutConstraint.activate([
            line.widthAnchor.constraint(equalToConstant: 1),
            line.heightAnchor.constraint(equalToConstant: dividerHeight),
        ])
        return line
    }
}
