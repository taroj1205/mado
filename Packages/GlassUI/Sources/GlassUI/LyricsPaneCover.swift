import AppKit

final class LyricsPaneCover: NSView {
    static let size: CGFloat = 188
    private static let radius: CGFloat = 14
    private static let noteSize: CGFloat = 44
    private static let blankAlpha = (dark: 0.12, light: 0.07)
    private static let shadowRadius: CGFloat = 15
    private static let shadowDrop: CGFloat = 10
    private static let shadowOpacity = (dark: 0.35, light: 0.28)
    private static let fallbackScale: CGFloat = 2

    private let plate = CALayer()
    private let art = CALayer()
    private let note = NSImageView()
    private(set) var image: NSImage?

    override var wantsUpdateLayer: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        art.cornerRadius = Self.radius
        art.cornerCurve = .continuous
        art.masksToBounds = true
        art.contentsGravity = .resizeAspectFill
        plate.shadowRadius = Self.shadowRadius
        plate.shadowOffset = CGSize(width: 0, height: -Self.shadowDrop)
        plate.addSublayer(art)
        layer?.addSublayer(plate)
        note.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        note.symbolConfiguration = .init(pointSize: Self.noteSize, weight: .regular)
        note.contentTintColor = .tertiaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        addSubview(note)
        NSLayoutConstraint.activate([
            note.centerXAnchor.constraint(equalTo: centerXAnchor),
            note.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly {
            plate.frame = bounds
            plate.shadowPath =
                NSBezierPath(roundedRect: bounds, xRadius: Self.radius, yRadius: Self.radius)
                .cgPath
            art.frame = plate.bounds
        }
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let ink = dark ? NSColor.white : .black
            let blank = dark ? Self.blankAlpha.dark : Self.blankAlpha.light
            art.backgroundColor = image == nil ? ink.withAlphaComponent(blank).cgColor : nil
            plate.shadowColor = NSColor.black.cgColor
            let opacity = dark ? Self.shadowOpacity.dark : Self.shadowOpacity.light
            plate.shadowOpacity = image == nil ? 0 : Float(opacity)
        }
    }

    func show(_ image: NSImage?) {
        self.image = image
        note.isHidden = image != nil
        art.contents = image?.layerContents(
            forContentsScale: unsafe window?.backingScaleFactor ?? Self.fallbackScale)
        needsDisplay = true
    }
}
