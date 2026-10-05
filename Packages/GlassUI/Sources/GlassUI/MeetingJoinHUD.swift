public import AppCore
public import AppKit

@MainActor
public final class MeetingJoinHUD {
    private static let width: CGFloat = 400
    private static let radius: CGFloat = 20
    private static let padding: CGFloat = 16
    private static let spacing: CGFloat = 12
    private static let rowGap: CGFloat = 10
    private static let tileSize: CGFloat = 36
    private static let tileRadius: CGFloat = 9
    private static let tileSymbol: CGFloat = 16
    private static let avatarSize: CGFloat = 24
    private static let avatarOverlap: CGFloat = -5
    private static let avatarFont: CGFloat = 9
    private static let titleSize: CGFloat = 14
    private static let detailSize: CGFloat = 12
    private static let buttonHeight: CGFloat = 34
    private static let buttonGap: CGFloat = 8
    private static let snoozeTitle = "Snooze 1 min"
    private static let half: CGFloat = 0.5
    private static let avatarColours: [NSColor] = [.systemPurple, .systemOrange, .systemGreen]

    public var onJoin: (() -> Void)?
    public var onSnooze: (() -> Void)?
    public var onDismiss: (() -> Void)?
    public var isShown: Bool { panel.isVisible }

    private let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .rounded(radius))

    public init() {
        panel.ignoresMouseEvents = false
        let border = GlassBorder(radius: Self.radius)
        border.frame = panel.glass.container.bounds
        border.autoresizingMask = [.width, .height]
        panel.glass.container.addSubview(border)
    }

    private static func label(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = weight == .semibold ? .labelColor : .secondaryLabelColor
        field.lineBreakMode = .byTruncatingTail
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    private static func circle(_ size: CGFloat, fill: NSColor, radius: CGFloat) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = radius
        box.fillColor = fill
        box.contentViewMargins = .zero
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: size),
            box.heightAnchor.constraint(equalToConstant: size),
        ])
        return box
    }

    private static func centred(_ view: NSView, in box: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(view)
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            view.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
    }

    private static func tile() -> NSView {
        let tile = circle(tileSize, fill: .systemBlue, radius: tileRadius)
        let symbol = NSImageView(
            image: NSImage(systemSymbolName: "video", accessibilityDescription: nil) ?? NSImage())
        symbol.symbolConfiguration = .init(pointSize: tileSymbol, weight: .medium)
        symbol.contentTintColor = .white
        centred(symbol, in: tile)
        return tile
    }

    private static func avatar(_ initials: String, colour: NSColor) -> NSView {
        let avatar = circle(avatarSize, fill: colour, radius: avatarSize * half)
        let text = NSTextField(labelWithString: initials)
        text.font = .systemFont(ofSize: avatarFont, weight: .bold)
        text.textColor = .white
        centred(text, in: avatar)
        return avatar
    }

    public func show(
        _ prompt: JoinPrompt, keys: [String], placing place: (CGSize) -> CGRect
    ) {
        let content = content(for: prompt, keys: keys)
        panel.glass.contentView = content
        panel.setFrame(place(content.fittingSize), display: true)
        panel.orderFrontRegardless()
    }

    public func hide() {
        panel.orderOut(nil)
    }

    private func content(for prompt: JoinPrompt, keys: [String]) -> NSView {
        let title = Self.label(prompt.event.title, size: Self.titleSize, weight: .semibold)
        let detail = Self.label(prompt.detail, size: Self.detailSize, weight: .regular)
        let text = NSStackView(views: [title, detail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 1
        let header = NSStackView(views: [Self.tile(), text])
        header.spacing = Self.spacing
        var rows: [NSView] = [header]
        if !prompt.initials.isEmpty {
            rows.append(attendees(of: prompt))
        }
        rows.append(buttons(keys: keys))
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.rowGap
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        var fills = rows.map { row in
            row.widthAnchor.constraint(
                equalTo: stack.widthAnchor, constant: -(Self.padding + Self.padding))
        }
        fills.append(stack.widthAnchor.constraint(equalToConstant: Self.width))
        NSLayoutConstraint.activate(
            fills + [
                stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                stack.topAnchor.constraint(equalTo: content.topAnchor),
                stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        content.setAccessibilityElement(true)
        content.setAccessibilityRole(.group)
        content.setAccessibilityLabel("\(prompt.event.title), \(prompt.detail)")
        return content
    }

    private func attendees(of prompt: JoinPrompt) -> NSView {
        let faces = NSStackView(
            views: prompt.initials.enumerated().map { index, initials in
                Self.avatar(initials, colour: Self.avatarColours[index % Self.avatarColours.count])
            })
        faces.spacing = Self.avatarOverlap
        let names = Self.label(prompt.attendees, size: Self.detailSize, weight: .regular)
        let row = NSStackView(views: [faces, names])
        row.spacing = Self.rowGap
        return row
    }

    private func buttons(keys: [String]) -> NSView {
        let join = CapsuleButton.accent("Join", keys: keys, height: Self.buttonHeight)
        join.onPress = { [weak self] in self?.onJoin?() }
        let snooze = secondary(Self.snoozeTitle) { [weak self] in self?.onSnooze?() }
        let dismiss = secondary("Dismiss") { [weak self] in self?.onDismiss?() }
        join.setContentHuggingPriority(.defaultLow, for: .horizontal)
        for button in [snooze, dismiss] {
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        let row = NSStackView(views: [join, snooze, dismiss])
        row.distribution = .fill
        row.spacing = Self.buttonGap
        return row
    }

    private func secondary(_ title: String, press: @escaping () -> Void) -> CapsuleButton {
        let button = CapsuleButton(title, keys: [], symbol: nil, height: Self.buttonHeight)
        button.fillColor = FloatingCapsule.keycapFill
        button.cornerRadius = Self.buttonHeight * Self.half
        button.onPress = press
        return button
    }
}
