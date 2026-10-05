import AppKit

final class WidgetCover: NSView {
    static let size: CGFloat = 52
    private static let radius: CGFloat = 10
    private static let noteSize: CGFloat = 20
    private static let pausedScale: CGFloat = 0.88
    private static let edgeWidth: CGFloat = 0.5
    private static let edgeAlpha = (dark: 0.18, light: 0.1)
    private static let blankAlpha = (dark: 0.12, light: 0.07)
    private static let shadowRadius: CGFloat = 10
    private static let shadowDrop: CGFloat = 4
    private static let playingShadow: Float = 0.55
    private static let pausedShadow: Float = 0.2
    private static let stiffness = 260.0
    private static let damping = 18.0
    private static let fadeSeconds = 0.25
    private static let fallbackScale: CGFloat = 2

    private let plate = CALayer()
    private let art = CALayer()
    private let note = NSImageView()
    private var playing = true
    private var tint: NSColor?
    private(set) var image: NSImage?

    override var wantsUpdateLayer: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size, height: Self.size)
    }

    private var scale: CGFloat {
        playing ? 1 : Self.pausedScale
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        art.cornerRadius = Self.radius
        art.cornerCurve = .continuous
        art.masksToBounds = true
        art.borderWidth = Self.edgeWidth
        art.contentsGravity = .resizeAspectFill
        plate.shadowRadius = Self.shadowRadius
        plate.shadowOffset = CGSize(width: 0, height: -Self.shadowDrop)
        plate.addSublayer(art)
        layer?.addSublayer(plate)
        note.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)
        note.symbolConfiguration = .init(pointSize: Self.noteSize, weight: .regular)
        note.contentTintColor = .secondaryLabelColor
        note.translatesAutoresizingMaskIntoConstraints = false
        addSubview(note)
        NSLayoutConstraint.activate([
            note.centerXAnchor.constraint(equalTo: centerXAnchor),
            note.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.quietly {
            plate.bounds = CGRect(origin: .zero, size: bounds.size)
            plate.position = CGPoint(x: bounds.midX, y: bounds.midY)
            plate.shadowPath =
                NSBezierPath(
                    roundedRect: plate.bounds, xRadius: Self.radius, yRadius: Self.radius
                ).cgPath
            art.frame = plate.bounds
        }
    }

    override func updateLayer() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let ink = dark ? NSColor.white : .black
            let edge = dark ? Self.edgeAlpha.dark : Self.edgeAlpha.light
            let blank = dark ? Self.blankAlpha.dark : Self.blankAlpha.light
            art.borderColor = ink.withAlphaComponent(edge).cgColor
            art.backgroundColor = image == nil ? ink.withAlphaComponent(blank).cgColor : nil
            plate.shadowColor = (tint ?? .black).cgColor
        }
    }

    func show(_ image: NSImage?, tint: NSColor?, animated: Bool) {
        self.image = image
        self.tint = tint
        note.isHidden = image != nil
        if animated {
            let fade = CATransition()
            fade.duration = Self.fadeSeconds
            art.add(fade, forKey: "swap")
        }
        art.contents = image?.layerContents(
            forContentsScale: unsafe window?.backingScaleFactor ?? Self.fallbackScale)
        showShadow()
        needsDisplay = true
    }

    func setPlaying(_ playing: Bool, animated: Bool) {
        guard playing != self.playing else { return }
        let start = scale
        self.playing = playing
        plate.transform = CATransform3DMakeScale(scale, scale, 1)
        showShadow()
        guard animated else { return }
        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = start
        spring.toValue = scale
        spring.stiffness = Self.stiffness
        spring.damping = Self.damping
        spring.duration = spring.settlingDuration
        plate.add(spring, forKey: "scale")
    }

    private func showShadow() {
        let opacity = playing ? Self.playingShadow : Self.pausedShadow
        plate.shadowOpacity = image == nil ? 0 : opacity
    }
}
