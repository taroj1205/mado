import AppKit

final class CameraNotice: NSView {
    struct Choice: Equatable {
        let title: String
        let action: CameraWindow.Action
    }

    struct Content: Equatable {
        let symbol: String
        let title: String
        let message: String
        let choice: Choice?
    }

    private static let badgeSide: CGFloat = 52
    private static let glyphSize: CGFloat = 22
    private static let titleSize: CGFloat = 15
    private static let messageSize: CGFloat = 12.5
    private static let messageWidth: CGFloat = 230
    private static let spacing: CGFloat = 6
    private static let buttonGap: CGFloat = 12
    private static let buttonHeight: CGFloat = 28
    private static let badgeAlpha: CGFloat = 0.09
    private static let half: CGFloat = 0.5

    var onAction: ((CameraWindow.Action) -> Void)?
    private(set) var content: Content?
    private let stack = NSStackView()
    private let spinner = Spinner()
    private var action: CameraWindow.Action?

    override var mouseDownCanMoveWindow: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Self.spacing
        for view in [stack, spinner] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            spinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func content(for phase: CameraWindow.Phase) -> Content? {
        switch phase {
        case .starting, .live:
            nil

        case .denied:
            Content(
                symbol: "video.slash", title: "Camera access is off",
                message: "Allow Mado under Privacy & Security, Camera in System Settings.",
                choice: Choice(title: "Open Settings", action: .openSettings))

        case .noCamera:
            Content(
                symbol: "video.slash", title: "No camera found",
                message: "Connect a camera and it shows up here on its own.", choice: nil)

        case .failed:
            Content(
                symbol: "exclamationmark.triangle", title: "Can't open the camera",
                message: "Another app may be holding it. Try again, or pick another camera.",
                choice: Choice(title: "Try Again", action: .retry))
        }
    }

    func show(_ phase: CameraWindow.Phase) {
        content = Self.content(for: phase)
        spinner.isHidden = phase != .starting
        isHidden = phase == .live
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.isHidden = content == nil
        guard let content else { return }
        let disc = makeBadge(content.symbol)
        stack.addArrangedSubview(disc)
        stack.setCustomSpacing(Self.buttonGap, after: disc)
        stack.addArrangedSubview(label(content.title, size: Self.titleSize, weight: .semibold))
        let message = label(
            content.message, size: Self.messageSize, weight: .regular, colour: .secondaryLabelColor)
        message.preferredMaxLayoutWidth = Self.messageWidth
        stack.addArrangedSubview(message)
        action = content.choice?.action
        guard let choice = content.choice else { return }
        let pill = PillButton(choice.title, height: Self.buttonHeight)
        pill.target = self
        pill.action = #selector(pressed)
        stack.addArrangedSubview(pill)
        stack.setCustomSpacing(Self.buttonGap, after: message)
    }

    private func makeBadge(_ symbol: String) -> NSView {
        let disc = NSView()
        disc.wantsLayer = true
        disc.layer?.cornerRadius = Self.badgeSide * Self.half
        disc.layer?.backgroundColor =
            NSColor.labelColor.withAlphaComponent(Self.badgeAlpha).cgColor
        let glyph = NSImageView(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: Self.glyphSize, weight: .medium))
                ?? NSImage())
        glyph.contentTintColor = .secondaryLabelColor
        glyph.translatesAutoresizingMaskIntoConstraints = false
        disc.translatesAutoresizingMaskIntoConstraints = false
        disc.addSubview(glyph)
        NSLayoutConstraint.activate([
            disc.widthAnchor.constraint(equalToConstant: Self.badgeSide),
            disc.heightAnchor.constraint(equalToConstant: Self.badgeSide),
            glyph.centerXAnchor.constraint(equalTo: disc.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: disc.centerYAnchor),
        ])
        return disc
    }

    private func label(
        _ text: String, size: CGFloat, weight: NSFont.Weight, colour: NSColor = .labelColor
    ) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = colour
        field.alignment = .center
        return field
    }

    @objc
    private func pressed() {
        if let action { onAction?(action) }
    }
}
