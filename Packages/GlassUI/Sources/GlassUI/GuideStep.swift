import AppKit

final class GuideStep: NSView {
    enum State {
        case active
        case done
        case pending
    }

    private static let radius: CGFloat = 14
    private static let paddingX: CGFloat = 16
    private static let paddingY: CGFloat = 14
    private static let gap: CGFloat = 14
    private static let rowGap: CGFloat = 8
    private static let badgeSize: CGFloat = 26
    private static let badgeRadius: CGFloat = 13
    private static let ringWidth: CGFloat = 2
    private static let activeAlpha = 0.28
    private static let pendingAlpha = 0.45
    private static let titleSize: CGFloat = 14
    private static let detailSize: CGFloat = 12.5
    private static let numberSize: CGFloat = 13

    private(set) var state = State.pending {
        didSet { needsDisplay = true }
    }

    override var wantsUpdateLayer: Bool { true }

    private let position: Int
    private let badge = GuideStep.box(radius: badgeRadius, fill: .clear)
    private let number: NSTextField
    private let check = NSImageView()

    init(_ position: Int, title: String, detail: String, extras: [NSView]) {
        self.position = position
        number = NSTextField(labelWithString: "\(position)")
        super.init(frame: .zero)
        wantsLayer = true
        setUpBadge()
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.font = .systemFont(ofSize: Self.detailSize)
        detailLabel.textColor = .secondaryLabelColor
        let text = NSStackView(views: [titleLabel, detailLabel] + extras)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = Self.rowGap
        for view in [detailLabel] + extras {
            view.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        }
        let row = NSStackView(views: [badge, text])
        row.alignment = .top
        row.distribution = .fill
        row.spacing = Self.gap
        Self.embed(row, in: self, horizontal: Self.paddingX, vertical: Self.paddingY)
        show(.pending)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func box(radius: CGFloat, fill: NSColor) -> NSBox {
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.borderWidth = 0
        box.cornerRadius = radius
        box.fillColor = fill
        return box
    }

    static func embed(_ view: NSView, in box: NSView, horizontal: CGFloat, vertical: CGFloat) {
        view.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: box.topAnchor, constant: vertical),
            view.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -vertical),
            view.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: horizontal),
            view.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -horizontal),
        ])
    }

    override func updateLayer() {
        let fill: NSColor = state == .active ? .tertiarySystemFill : .quaternarySystemFill
        layer?.backgroundColor = fill.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = Self.radius
    }

    func show(_ state: State) {
        self.state = state
        let accent = NSColor.controlAccentColor
        alphaValue = state == .pending ? Self.pendingAlpha : 1
        check.isHidden = state != .done
        number.isHidden = state == .done
        number.textColor = state == .active ? .labelColor : .secondaryLabelColor
        badge.borderWidth = state == .active ? Self.ringWidth : 0
        badge.borderColor = accent
        badge.fillColor =
            switch state {
            case .active: accent.withAlphaComponent(Self.activeAlpha)
            case .done: accent
            case .pending: .tertiarySystemFill
            }
        badge.setAccessibilityLabel(state == .done ? "Step \(position), done" : "Step \(position)")
    }

    private func setUpBadge() {
        number.font = .systemFont(ofSize: Self.numberSize, weight: .bold)
        check.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
        check.symbolConfiguration = .init(pointSize: Self.numberSize, weight: .heavy)
        check.contentTintColor = .white
        badge.setAccessibilityElement(true)
        badge.setAccessibilityRole(.image)
        for mark in [number, check] {
            mark.translatesAutoresizingMaskIntoConstraints = false
            badge.addSubview(mark)
            mark.centerXAnchor.constraint(equalTo: badge.centerXAnchor).isActive = true
            mark.centerYAnchor.constraint(equalTo: badge.centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            badge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
        ])
    }
}
