public import AppKit

public final class SpotlightGuideView: NSView {
    private final class StatusSwitch: NSSwitch {
        override func hitTest(_: NSPoint) -> NSView? {
            nil
        }
    }

    private static let keyboardSettings = URL(
        string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    private static let margin: CGFloat = 32
    private static let crumbTop: CGFloat = 18
    private static let contentTop: CGFloat = 51
    private static let headerBottom: CGFloat = 2
    private static let bottom: CGFloat = 24
    private static let gap: CGFloat = 14
    private static let headerGap: CGFloat = 4
    private static let rowGap: CGFloat = 8
    private static let keyGap: CGFloat = 4
    private static let titleSize: CGFloat = 22
    private static let bodySize: CGFloat = 13
    private static let smallSize: CGFloat = 12.5
    private static let crumbSize: CGFloat = 12
    private static let keySize: CGFloat = 11
    private static let iconSize: CGFloat = 13
    private static let rowRadius: CGFloat = 10
    private static let rowPaddingX: CGFloat = 12
    private static let statusHeight: CGFloat = 38
    private static let buttonRowHeight: CGFloat = 26
    private static let chipHeight: CGFloat = 36
    private static let chipRing: CGFloat = 3
    private static let keyHeight: CGFloat = 18
    private static let keyRadius: CGFloat = 5
    private static let keyInset: CGFloat = 10
    private static let ringAlpha = 0.22
    private static let borderAlpha = 0.6
    private static let insetAlpha = (dark: 0.22, light: 0.5)
    private static let insetFill = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .black.withAlphaComponent(insetAlpha.dark)
            : .white.withAlphaComponent(insetAlpha.light)
    }

    public var onUseOptionSpace: (() -> Void)?
    public var onClose: (() -> Void)?

    let spotlight: NSSwitch = StatusSwitch()
    let useOptionSpace = NSButton()
    let skip = NSButton(title: "Skip", target: nil, action: nil)
    let finish = NSButton(title: "Continue", target: nil, action: nil)
    private(set) var steps: [GuideStep] = []

    public init() {
        super.init(frame: .zero)
        addStep(
            "Free up ⌘Space in System Settings",
            "Keyboard › Keyboard Shortcuts › Spotlight — turn off “Show Spotlight search”, or "
                + "move it to another key.",
            [spotlightRow(), openSettingsButton()])
        addStep(
            "Give ⌘Space to Mado",
            "Mado now listens for ⌘Space. If nothing happens, step 1 didn’t stick — reopen it.",
            [pressRow()])
        addStep(
            "Done", "Until ⌘Space is free, ⌥Space also opens Mado, so it is never out of reach.",
            [])
        layOut()
        show(spotlightHasCommandSpace: true, commandSpaceReaches: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func label(_ text: String, size: CGFloat, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = color
        return label
    }

    private static func keycap(_ text: String) -> NSView {
        let key = GuideStep.box(radius: keyRadius, fill: .tertiarySystemFill)
        let name = label(text, size: keySize, color: .labelColor)
        name.font = .systemFont(ofSize: keySize, weight: .medium)
        name.translatesAutoresizingMaskIntoConstraints = false
        key.addSubview(name)
        let snug = key.widthAnchor.constraint(equalTo: name.widthAnchor, constant: keyInset)
        snug.priority = .defaultHigh
        NSLayoutConstraint.activate([
            snug,
            key.heightAnchor.constraint(equalToConstant: keyHeight),
            key.widthAnchor.constraint(greaterThanOrEqualToConstant: keyHeight),
            key.widthAnchor.constraint(
                greaterThanOrEqualTo: name.widthAnchor, constant: keyInset),
            name.centerXAnchor.constraint(equalTo: key.centerXAnchor),
            name.centerYAnchor.constraint(equalTo: key.centerYAnchor),
        ])
        return key
    }

    public func show(spotlightHasCommandSpace: Bool, commandSpaceReaches: Bool) {
        spotlight.state = spotlightHasCommandSpace ? .on : .off
        let states: [GuideStep.State] =
            if commandSpaceReaches {
                [.done, .done, .done]
            } else if spotlightHasCommandSpace {
                [.active, .pending, .pending]
            } else {
                [.done, .active, .pending]
            }
        for (step, state) in zip(steps, states) {
            step.show(state)
        }
    }

    private func addStep(_ title: String, _ detail: String, _ extras: [NSView]) {
        steps.append(GuideStep(steps.count + 1, title: title, detail: detail, extras: extras))
    }

    private func layOut() {
        let crumb = Self.label(
            "Settings › General › Launcher hotkey", size: Self.crumbSize,
            color: .secondaryLabelColor)
        let title = Self.label("Use ⌘Space for Mado", size: Self.titleSize, color: .labelColor)
        title.font = .systemFont(ofSize: Self.titleSize, weight: .bold)
        let subtitle = Self.label(
            "Spotlight owns ⌘Space until you free it. Two steps, and you can undo either one "
                + "later.", size: Self.bodySize, color: .secondaryLabelColor)
        let header = NSStackView(views: [title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = Self.headerGap
        let content = NSStackView(views: [header] + steps)
        content.orientation = .vertical
        content.spacing = Self.gap
        content.setCustomSpacing(Self.gap + Self.headerBottom, after: header)
        for view in content.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }
        let footer = footerRow()
        for view in [crumb, content, footer] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            crumb.topAnchor.constraint(equalTo: topAnchor, constant: Self.crumbTop),
            crumb.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.margin),
            content.topAnchor.constraint(equalTo: topAnchor, constant: Self.contentTop),
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.margin),
            content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.margin),
            footer.topAnchor.constraint(greaterThanOrEqualTo: content.bottomAnchor),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.bottom),
        ])
    }

    private func spotlightRow() -> NSView {
        let icon = NSImageView(
            image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
                ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        spotlight.setAccessibilityEnabled(false)
        spotlight.refusesFirstResponder = true
        spotlight.setAccessibilityLabel("Show Spotlight search")
        let name = Self.label("Show Spotlight search", size: Self.smallSize, color: .labelColor)
        let row = NSStackView(views: [
            icon, name, Self.label("⌘Space", size: Self.smallSize, color: .tertiaryLabelColor),
        ])
        row.setViews([spotlight], in: .trailing)
        row.spacing = Self.rowGap
        row.setCustomSpacing(Self.keyGap, after: name)
        let box = GuideStep.box(radius: Self.rowRadius, fill: Self.insetFill)
        GuideStep.embed(row, in: box, horizontal: Self.rowPaddingX, vertical: 0)
        box.heightAnchor.constraint(equalToConstant: Self.statusHeight).isActive = true
        return box
    }

    private func openSettingsButton() -> NSView {
        let button = NSButton(
            title: "Open Keyboard Shortcuts",
            image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
                ?? NSImage(),
            target: self, action: #selector(openKeyboardSettings))
        button.imagePosition = .imageLeading
        if #available(macOS 26, *) {
            button.borderShape = .capsule
        }
        let row = NSStackView(views: [button])
        row.heightAnchor.constraint(equalToConstant: Self.buttonRowHeight).isActive = true
        return row
    }

    private func pressRow() -> NSView {
        let keys = NSStackView(views: ["⌘", "Space"].map(Self.keycap))
        keys.spacing = Self.keyGap
        keys.setHuggingPriority(.required, for: .horizontal)
        let field = GuideStep.box(radius: Self.rowRadius, fill: Self.insetFill)
        field.borderWidth = 1
        field.borderColor = .controlAccentColor.withAlphaComponent(Self.borderAlpha)
        GuideStep.embed(keys, in: field, horizontal: Self.rowPaddingX, vertical: 0)
        field.heightAnchor.constraint(equalToConstant: Self.chipHeight).isActive = true
        let ring = GuideStep.box(radius: Self.rowRadius + Self.chipRing, fill: .clear)
        ring.borderWidth = Self.chipRing
        ring.borderColor = .controlAccentColor.withAlphaComponent(Self.ringAlpha)
        let chip = NSView()
        for view in [ring, field] {
            view.translatesAutoresizingMaskIntoConstraints = false
            chip.addSubview(view)
        }
        GuideStep.embed(field, in: chip, horizontal: 0, vertical: 0)
        GuideStep.embed(ring, in: chip, horizontal: -Self.chipRing, vertical: -Self.chipRing)
        let hint = Self.label(
            "Press ⌘Space now to confirm it reaches Mado", size: Self.smallSize,
            color: .secondaryLabelColor)
        let row = NSStackView(views: [chip, hint])
        row.spacing = Self.rowPaddingX
        return row
    }

    private func footerRow() -> NSView {
        useOptionSpace.attributedTitle = NSAttributedString(
            string: "Use ⌥Space instead",
            attributes: [
                .foregroundColor: NSColor.controlAccentColor,
                .font: NSFont.systemFont(ofSize: Self.bodySize),
            ])
        useOptionSpace.isBordered = false
        useOptionSpace.target = self
        useOptionSpace.action = #selector(chooseOptionSpace)
        skip.keyEquivalent = "\u{1b}"
        skip.controlSize = .large
        finish.controlSize = .large
        finish.keyEquivalent = "\r"
        for button in [skip, finish] {
            button.target = self
            button.action = #selector(close)
        }
        let row = NSStackView(views: [useOptionSpace])
        row.setViews([skip, finish], in: .trailing)
        row.spacing = Self.rowGap
        return row
    }

    @objc
    private func openKeyboardSettings() {
        if let url = Self.keyboardSettings {
            NSWorkspace.shared.open(url)
        }
    }

    @objc
    private func chooseOptionSpace() {
        onUseOptionSpace?()
    }

    @objc
    private func close() {
        onClose?()
    }
}
