public import AppKit

public final class RadialEditor: NSView {
    public enum Slot: CaseIterable, Sendable {
        case ring
        case right
        case bottomRight
        case bottom
        case bottomLeft
        case left
        case topLeft
        case top
        case topRight

        var name: String {
            switch self {
            case .ring: "Ring"
            case .right: "Right"
            case .bottomRight: "Bottom right"
            case .bottom: "Bottom"
            case .bottomLeft: "Bottom left"
            case .left: "Left"
            case .topLeft: "Top left"
            case .top: "Top"
            case .topRight: "Top right"
            }
        }
    }

    public struct Choice: Equatable, Sendable {
        public let id: String
        public let title: String
        public let detail: String?
        public let glyph: CGRect
        public let cycles: Bool

        public init(id: String, title: String, detail: String?, glyph: CGRect, cycles: Bool) {
            self.id = id
            self.title = title
            self.detail = detail
            self.glyph = glyph
            self.cycles = cycles
        }
    }

    public struct Group: Sendable {
        public let title: String
        public let choices: [Choice]

        public init(title: String, choices: [Choice]) {
            self.title = title
            self.choices = choices
        }
    }

    enum Selection: Equatable {
        case hole
        case slot(Slot)
    }

    private final class Board: NSView {
        override var isFlipped: Bool { true }
    }

    private static let side: CGFloat = 300
    private static let boardRadius: CGFloat = 16
    private static let ringSide: CGFloat = 104
    private static let holeSide: CGFloat = 52
    private static let slotSide: CGFloat = 44
    private static let slotDistance: CGFloat = 112
    private static let sectorDegrees: CGFloat = 45
    private static let halfTurn: CGFloat = 180
    private static let half: CGFloat = 0.5
    private static let gap: CGFloat = 14
    private static let captionGap: CGFloat = 8
    private static let captionSize: CGFloat = 11.5
    private static let caption =
        "Release in the hole to cancel, on the ring for the ring action, past the ring for "
        + "a direction."
    private static let fillAlpha = (dark: 0.18, light: 0.04)
    private static let edgeAlpha = (dark: 0.06, light: 0.08)
    private static let boardFill = SheetForm.adaptive(
        dark: .black.withAlphaComponent(fillAlpha.dark),
        light: .black.withAlphaComponent(fillAlpha.light))
    private static let boardEdge = SheetForm.adaptive(
        dark: .white.withAlphaComponent(edgeAlpha.dark),
        light: .black.withAlphaComponent(edgeAlpha.light))

    public var actions: [Slot: String] = [:] {
        didSet { render() }
    }
    public var onPick: ((Slot, String) -> Void)?

    private(set) var selection = Selection.slot(.ring)
    private(set) var slots: [Slot: RadialSlotButton] = [:]
    private(set) lazy var hole = RadialSlotButton(
        .hole, side: Self.holeSide, target: self, action: #selector(pickHole))
    let inspector: RadialInspector
    private let choices: [String: Choice]

    public init(groups: [Group]) {
        choices = Dictionary(groups.flatMap(\.choices).map { ($0.id, $0) }) { first, _ in first }
        inspector = RadialInspector(groups: groups)
        super.init(frame: .zero)
        inspector.onChoose = { [weak self] in self?.choose($0) }
        let stack = NSStackView(views: [column(), inspector])
        stack.alignment = .top
        stack.distribution = .fill
        stack.spacing = Self.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func centre(of slot: Slot) -> CGPoint {
        let middle = side * half
        guard let index = Slot.allCases.firstIndex(of: slot), slot != .ring else {
            return CGPoint(x: middle, y: middle)
        }
        let radians = CGFloat(index - 1) * sectorDegrees * .pi / halfTurn
        return CGPoint(
            x: middle + slotDistance * cos(radians), y: middle + slotDistance * sin(radians))
    }

    private func column() -> NSView {
        let board = Board()
        for slot in Slot.allCases {
            let length = slot == .ring ? Self.ringSide : Self.slotSide
            let button = RadialSlotButton(
                slot == .ring ? .ring : .direction, side: length, target: self,
                action: #selector(pickSlot))
            let point = Self.centre(of: slot)
            button.setFrameOrigin(
                CGPoint(x: point.x - length * Self.half, y: point.y - length * Self.half))
            slots[slot] = button
            board.addSubview(button)
        }
        let middle = Self.side * Self.half - Self.holeSide * Self.half
        hole.setFrameOrigin(CGPoint(x: middle, y: middle))
        hole.setAccessibilityLabel("Centre hole: cancel. Fixed")
        board.addSubview(hole)
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = Self.boardRadius
        box.fillColor = Self.boardFill
        box.borderColor = Self.boardEdge
        box.contentViewMargins = .zero
        box.contentView = board
        let note = NSTextField(wrappingLabelWithString: Self.caption)
        note.font = .systemFont(ofSize: Self.captionSize)
        note.textColor = .secondaryLabelColor
        note.preferredMaxLayoutWidth = Self.side
        let stack = NSStackView(views: [box, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.captionGap
        stack.setHuggingPriority(.required, for: .horizontal)
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: Self.side),
            box.heightAnchor.constraint(equalToConstant: Self.side),
            note.widthAnchor.constraint(equalToConstant: Self.side),
        ])
        return stack
    }

    @objc
    private func pickSlot(_ sender: RadialSlotButton) {
        guard let slot = slots.first(where: { $0.value === sender })?.key else { return }
        selection = .slot(slot)
        render()
    }

    @objc
    private func pickHole() {
        selection = .hole
        render()
    }

    private func choose(_ id: String) {
        guard case .slot(let slot) = selection else { return }
        actions[slot] = id
        onPick?(slot, id)
    }

    private func render() {
        for (slot, button) in slots {
            let choice = actions[slot].flatMap { choices[$0] }
            button.area = choice?.glyph ?? .zero
            button.cycles = choice?.cycles ?? false
            button.isChosen = selection == .slot(slot)
            button.setAccessibilityLabel("\(slot.name): \(choice?.title ?? "Nothing")")
        }
        hole.isChosen = selection == .hole
        switch selection {
        case .hole:
            inspector.show(
                title: "Hole · Cancel", subtitle: "Fixed — not customisable", chosen: nil)

        case .slot(let slot):
            let subtitle =
                slot == .ring
                ? "Release on the ring itself"
                : "Release past the ring, toward \(slot.name.lowercased())"
            inspector.show(title: slot.name, subtitle: subtitle, chosen: actions[slot] ?? "")
        }
    }
}
