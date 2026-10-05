public import AppKit

@MainActor
public final class ColourLoupe {
    public enum Input: Equatable, Sendable {
        case moved(CGPoint)
        case nudged(across: Int, down: Int)
        case picked
        case cancelled
    }

    public struct Reading {
        public let grid: CGImage
        public let swatch: NSColor
        public let hex: String
        public let detail: String
        public let centre: CGPoint

        public init(grid: CGImage, swatch: NSColor, hex: String, detail: String, centre: CGPoint) {
            self.grid = grid
            self.swatch = swatch
            self.hex = hex
            self.detail = detail
            self.centre = centre
        }
    }

    static let hintText = "Click copies · arrows or HJKL nudge 1 px · esc cancels"
    static let cardWidth: CGFloat = 240
    static let gap: CGFloat = 10
    private static let radius: CGFloat = 18
    private static let padding: CGFloat = 12
    private static let spacing: CGFloat = 8
    private static let swatchSize: CGFloat = 28
    private static let swatchRadius: CGFloat = 8
    private static let swatchBorderAlpha = 0.3
    private static let hexSize: CGFloat = 14
    private static let noteSize: CGFloat = 11.5
    private static let half: CGFloat = 0.5

    let lens = LoupeLens(frame: CGRect(x: 0, y: 0, width: LoupeLens.size, height: LoupeLens.size))
    let swatch = NSView()
    let hex = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let hint = NSTextField(wrappingLabelWithString: hintText)
    private(set) lazy var card = makeCard()
    private(set) var panels: [LoupePanel] = []
    var pointer = { NSEvent.mouseLocation }
    public var onInput: ((Input) -> Void)?

    public var isVisible: Bool { !panels.isEmpty }

    public init() {
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = Self.swatchRadius
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.white.withAlphaComponent(Self.swatchBorderAlpha).cgColor
        hex.font = .monospacedSystemFont(ofSize: Self.hexSize, weight: .semibold)
        for note in [detail, hint] {
            note.font = .systemFont(ofSize: Self.noteSize)
            note.textColor = .secondaryLabelColor
        }
        hint.preferredMaxLayoutWidth = Self.cardWidth - Self.padding - Self.padding
    }

    static func frames(around centre: CGPoint, card: CGSize, in bounds: CGRect) -> (
        lens: CGRect, card: CGRect
    ) {
        let circle = CGRect(
            x: (centre.x - LoupeLens.size * half).rounded(),
            y: (centre.y - LoupeLens.size * half).rounded(), width: LoupeLens.size,
            height: LoupeLens.size)
        let below = circle.minY - gap - card.height
        let left = min(max(centre.x - card.width * half, bounds.minX), bounds.maxX - card.width)
        return (
            circle,
            CGRect(
                x: left.rounded(), y: below >= bounds.minY ? below : circle.maxY + gap,
                width: card.width, height: card.height)
        )
    }

    private func makeCard() -> GlassView {
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: Self.swatchSize),
            swatch.heightAnchor.constraint(equalToConstant: Self.swatchSize),
        ])
        let values = NSStackView(views: [hex, detail])
        values.orientation = .vertical
        values.alignment = .leading
        values.spacing = 0
        let row = NSStackView(views: [swatch, values])
        row.spacing = Self.gap
        let column = NSStackView(views: [row, hint])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = Self.spacing
        column.edgeInsets = NSEdgeInsets(
            top: Self.padding, left: Self.padding, bottom: Self.padding, right: Self.padding)
        let glass = FloatingCapsule.glass(column, radius: Self.radius)
        column.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            glass.widthAnchor.constraint(equalToConstant: Self.cardWidth),
            column.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            column.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            column.topAnchor.constraint(equalTo: glass.topAnchor),
            column.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        glass.setAccessibilityElement(true)
        glass.setAccessibilityRole(.group)
        return glass
    }

    public func show(on screens: [NSScreen]) {
        hide()
        let mouse = pointer()
        panels = screens.map { screen in
            let panel = LoupePanel(frame: screen.frame)
            panel.onInput = { [weak self] input in self?.receive(input) }
            return panel
        }
        let main = panels.first { NSMouseInRect(mouse, $0.frame, false) } ?? panels.first
        main?.takesKeys = true
        for panel in panels {
            panel.orderFrontRegardless()
        }
        main?.makeKey()
    }

    public func show(_ reading: Reading) {
        guard
            let panel = panels.first(where: { NSMouseInRect(reading.centre, $0.frame, false) }),
            let view = panel.contentView
        else { return }
        if !lens.isDescendant(of: view) {
            view.addSubview(lens)
            view.addSubview(card)
        }
        lens.grid = reading.grid
        swatch.layer?.backgroundColor = reading.swatch.cgColor
        hex.stringValue = reading.hex
        detail.stringValue = reading.detail
        card.setAccessibilityLabel("Colour \(reading.hex), \(reading.detail)")
        let frames = Self.frames(
            around: panel.convertPoint(fromScreen: reading.centre), card: card.fittingSize,
            in: view.bounds)
        lens.frame = frames.lens
        card.frame = frames.card
    }

    public func hide() {
        let shown = panels
        panels = []
        lens.removeFromSuperview()
        card.removeFromSuperview()
        for panel in shown {
            panel.orderOut(nil)
        }
    }

    private func receive(_ input: Input) {
        guard isVisible else { return }
        onInput?(input)
    }
}
