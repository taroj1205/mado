public import AppKit

final class ColourCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("colour")
    private static let cardTop: CGFloat = 8
    private static let cardSide: CGFloat = 4
    private static let cardBottom: CGFloat = 4
    private static let cardRadius: CGFloat = 16
    private static let cardBorder: CGFloat = 1
    private static let cardAlpha = (dark: 0.06, light: 0.04)
    private static let cardPadding: CGFloat = 16
    private static let cardPaddingSide: CGFloat = 18
    private static let swatchSize: CGFloat = 96
    private static let swatchRadius: CGFloat = 20
    private static let swatchBorder: CGFloat = 1
    private static let swatchBorderAlpha = 0.18
    private static let swatchShadowAlpha = 0.35
    private static let swatchShadowBlur: CGFloat = 24
    private static let swatchShadowDrop: CGFloat = -8
    private static let gap: CGFloat = 18
    private static let columnGap: CGFloat = 10
    private static let labelGap: CGFloat = 4
    private static let noteGap: CGFloat = 14
    private static let labelSize: CGFloat = 11.5
    private static let valueSize: CGFloat = 14
    private static let noteSize: CGFloat = 12.5
    private static let cardTint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .white.withAlphaComponent(cardAlpha.dark) : .black.withAlphaComponent(cardAlpha.light)
    }

    let card = NSBox()
    let swatch = NSBox()
    let hex = NSTextField(labelWithString: "")
    let rgb = NSTextField(labelWithString: "")
    let hsl = NSTextField(labelWithString: "")
    let closest = NSTextField(labelWithString: "")
    let onWhite = NSTextField(labelWithString: "")
    let onBlack = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        card.boxType = .custom
        card.cornerRadius = Self.cardRadius
        card.borderWidth = Self.cardBorder
        card.fillColor = Self.cardTint
        card.borderColor = Self.cardTint
        card.contentViewMargins = .zero
        swatch.boxType = .custom
        swatch.cornerRadius = Self.swatchRadius
        swatch.borderWidth = Self.swatchBorder
        swatch.borderColor = .white.withAlphaComponent(Self.swatchBorderAlpha)
        swatch.contentViewMargins = .zero
        swatch.wantsLayer = true
        for value in [hex, rgb, hsl] {
            value.font = .monospacedSystemFont(ofSize: Self.valueSize, weight: .regular)
            value.lineBreakMode = .byTruncatingTail
            value.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        for note in [closest, onWhite, onBlack] {
            note.font = .systemFont(ofSize: Self.noteSize)
            note.textColor = .secondaryLabelColor
            note.lineBreakMode = .byTruncatingTail
        }
        closest.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setAccessibilityChildren([])
        arrange()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func column(_ name: String, _ value: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: name)
        label.font = .systemFont(ofSize: labelSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [label, value])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = labelGap
        return stack
    }

    func show(_ colour: ResultList.ColourCard) {
        swatch.fillColor = colour.swatch
        let glow = NSShadow()
        glow.shadowBlurRadius = Self.swatchShadowBlur
        glow.shadowOffset = NSSize(width: 0, height: Self.swatchShadowDrop)
        glow.shadowColor = colour.swatch.withAlphaComponent(Self.swatchShadowAlpha)
        swatch.shadow = glow
        hex.stringValue = colour.hex
        rgb.stringValue = colour.rgb
        hsl.stringValue = colour.hsl
        let name = NSAttributedString(
            string: colour.closest,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.noteSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        let line = NSMutableAttributedString(
            string: "Closest system colour: ",
            attributes: [.font: closest.font as Any, .foregroundColor: closest.textColor as Any])
        line.append(name)
        closest.attributedStringValue = line
        onWhite.stringValue = "On white \(colour.onWhite)"
        onBlack.stringValue = "On black \(colour.onBlack)"
        setAccessibilityLabel(
            [
                "Colour \(colour.hex)", colour.rgb, colour.hsl,
                "closest system colour \(colour.closest)", "on white \(colour.onWhite)",
                "on black \(colour.onBlack)",
            ]
            .joined(separator: ", "))
    }

    private func arrange() {
        let values = NSStackView(views: [
            Self.column("HEX", hex), Self.column("RGB", rgb), Self.column("HSL", hsl),
        ])
        values.distribution = .fillEqually
        values.alignment = .top
        values.spacing = Self.columnGap
        let notes = NSStackView(views: [closest, onWhite, onBlack])
        notes.spacing = Self.noteGap
        let info = NSStackView(views: [values, notes])
        info.orientation = .vertical
        info.alignment = .leading
        info.spacing = Self.columnGap
        let content = NSStackView(views: [swatch, info])
        content.spacing = Self.gap
        content.edgeInsets = NSEdgeInsets(
            top: Self.cardPadding, left: Self.cardPaddingSide, bottom: Self.cardPadding,
            right: Self.cardPaddingSide)
        card.contentView = content
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: Self.cardTop),
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.cardSide),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.cardSide),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.cardBottom),
            swatch.widthAnchor.constraint(equalToConstant: Self.swatchSize),
            swatch.heightAnchor.constraint(equalToConstant: Self.swatchSize),
            values.widthAnchor.constraint(equalTo: info.widthAnchor),
            notes.widthAnchor.constraint(lessThanOrEqualTo: info.widthAnchor),
        ])
    }
}

extension ResultList {
    public struct ColourCard: Sendable, Equatable {
        public let swatch: NSColor
        public let hex: String
        public let rgb: String
        public let hsl: String
        public let closest: String
        public let onWhite: String
        public let onBlack: String

        public init(
            swatch: NSColor, hex: String, rgb: String, hsl: String, closest: String,
            onWhite: String, onBlack: String
        ) {
            self.swatch = swatch
            self.hex = hex
            self.rgb = rgb
            self.hsl = hsl
            self.closest = closest
            self.onWhite = onWhite
            self.onBlack = onBlack
        }
    }
}
