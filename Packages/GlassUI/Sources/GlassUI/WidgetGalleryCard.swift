import AppKit
import Symbols

final class WidgetGalleryCard: NSView {
    private static let radius: CGFloat = 16
    private static let padding: CGFloat = 12
    private static let gap: CGFloat = 8
    private static let textGap: CGFloat = 2
    private static let checkSize: CGFloat = 11
    private static let badgeGap: CGFloat = 4
    private static let nameSize: CGFloat = 13.5
    private static let summarySize: CGFloat = 12
    private static let badgeSize: CGFloat = 12
    private static let sizeSize: CGFloat = 11
    private static let sizeGap: CGFloat = 5
    private static let addHeight: CGFloat = 24
    private static let fade: TimeInterval = 0.2
    private static let hover: TimeInterval = 0.12

    let card: WidgetGallery.Card
    let add = PillButton("Add", height: addHeight)
    let added = NSStackView()
    private let check = NSImageView()
    private let lift = WidgetGalleryCard.box(
        fill: WidgetTile.selectedFill, edge: WidgetTile.selectedEdge)
    var onAdd: (() -> Void)?

    var isAdded = false {
        didSet {
            add.isHidden = isAdded
            added.isHidden = !isAdded
            guard isAdded, !oldValue, unsafe window != nil else { return }
            unsafe NSAccessibility.post(
                element: self, notification: .announcementRequested,
                userInfo: [.announcement: "\(card.name) added"])
            guard animates else { return }
            added.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.fade
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                added.animator().alphaValue = 1
            }
            check.addSymbolEffect(.bounce, options: .nonRepeating)
        }
    }

    private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    init(_ card: WidgetGallery.Card) {
        self.card = card
        super.init(frame: .zero)
        addSubview(Self.box(fill: WidgetTile.fill, edge: WidgetTile.edge))
        lift.alphaValue = 0
        addSubview(lift)
        let lines = NSStackView(views: [
            Self.label(card.name, size: Self.nameSize, color: .labelColor, weight: .semibold),
            Self.label(card.summary, size: Self.summarySize, color: .secondaryLabelColor),
        ])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = Self.textGap
        let header = top()
        let stack = NSStackView(views: [header, lines, size()])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.padding),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(card.name)
        isAdded = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func box(fill: NSColor, edge: NSColor) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = radius
        box.borderWidth = 1
        box.fillColor = fill
        box.borderColor = edge
        box.autoresizingMask = [.width, .height]
        return box
    }

    private static func label(
        _ text: String, size: CGFloat, color: NSColor, weight: NSFont.Weight = .regular
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self))
    }

    override func mouseEntered(with _: NSEvent) {
        hover(true)
    }

    override func mouseExited(with _: NSEvent) {
        hover(false)
    }

    private func hover(_ isOver: Bool) {
        guard animates else {
            lift.alphaValue = isOver ? 1 : 0
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.hover
            lift.animator().alphaValue = isOver ? 1 : 0
        }
    }

    private func top() -> NSView {
        check.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        check.symbolConfiguration = .init(pointSize: Self.checkSize, weight: .bold)
        check.contentTintColor = .systemGreen
        let badge = Self.label(
            "Added", size: Self.badgeSize, color: .systemGreen, weight: .semibold)
        added.setViews([check, badge], in: .leading)
        added.spacing = Self.badgeGap
        add.target = self
        add.action = #selector(pressed)
        add.setAccessibilityLabel("Add \(card.name)")
        let icon = WidgetGalleryIcon(symbol: card.symbol, colour: card.colour)
        let row = NSStackView(views: [icon, NSView(), add, added])
        row.distribution = .fill
        return row
    }

    private func size() -> NSView {
        let footprint = NSImageView(image: card.size.footprint)
        footprint.contentTintColor = .tertiaryLabelColor
        let row = NSStackView(views: [
            footprint,
            Self.label(card.size.title, size: Self.sizeSize, color: .tertiaryLabelColor),
        ])
        row.spacing = Self.sizeGap
        return row
    }

    @objc
    private func pressed() {
        onAdd?()
    }
}
