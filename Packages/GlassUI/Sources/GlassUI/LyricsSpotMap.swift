import AppKit

final class LyricsSpotMap: NSView {
    static let width: CGFloat = 360
    static let height: CGFloat = 225
    static let barHeight: CGFloat = 14
    static let edge: CGFloat = 10
    static let gap: CGFloat = 8
    static let cardWidth: CGFloat = 72
    static let cardHeight: CGFloat = 38
    static let islandWidth: CGFloat = 84
    static let islandHeight: CGFloat = 18
    static let typeWidth: CGFloat = 84
    static let typeHeight: CGFloat = 30
    static let pillWidth: CGFloat = 60
    static let pillHeight: CGFloat = 9
    static let dockWidth: CGFloat = 148
    static let dockHeight: CGFloat = 24
    static let dockBottom: CGFloat = 6
    static let menusEnd: CGFloat = 118
    static let statusStart: CGFloat = 298
    static let radius: CGFloat = 8
    private static let half: CGFloat = 0.5
    private static let pressed: CGFloat = 0.96
    private static let popFrom: CGFloat = 0.9
    private static let hoverSeconds = 0.14
    private static let damping: CGFloat = 13
    private static let stiffness: CGFloat = 240
    private static let slop: CGFloat = 4

    static let frames: [LyricsSpot: CGRect] = {
        let dock = dockFrame
        let top = barHeight + edge
        let card = CGSize(width: cardWidth, height: cardHeight)
        let type = CGSize(width: typeWidth, height: typeHeight)
        let island = CGSize(width: islandWidth, height: islandHeight)
        let pill = CGSize(width: pillWidth, height: pillHeight)
        let bottom = dock.minY - gap - card.height
        let right = width - edge - card.width
        let line = (barHeight - pill.height) * half
        let middle = dock.midY - type.height * half
        let reach = edge + card.width + gap
        return [
            .island: CGRect(
                origin: CGPoint(x: (width - island.width) * half, y: top), size: island),
            .corner(.topLeading): CGRect(origin: CGPoint(x: edge, y: top), size: card),
            .corner(.topTrailing): CGRect(origin: CGPoint(x: right, y: top), size: card),
            .corner(.bottomLeading): CGRect(origin: CGPoint(x: edge, y: bottom), size: card),
            .corner(.bottomTrailing): CGRect(origin: CGPoint(x: right, y: bottom), size: card),
            .menus: CGRect(origin: CGPoint(x: menusEnd + gap, y: line), size: pill),
            .menuBar: CGRect(
                origin: CGPoint(x: statusStart - gap - pill.width, y: line), size: pill),
            .desktop: CGRect(
                x: reach, y: bottom + card.height - type.height, width: width - reach - reach,
                height: type.height),
            .dock(.leading): CGRect(origin: CGPoint(x: edge, y: middle), size: type),
            .dock(.trailing): CGRect(
                origin: CGPoint(x: width - edge - type.width, y: middle), size: type),
        ]
    }()

    static var dockFrame: CGRect {
        CGRect(
            x: (width - dockWidth) * half, y: height - dockBottom - dockHeight, width: dockWidth,
            height: dockHeight)
    }

    var onPick: ((LyricsSpot) -> Void)?
    var isEnabled = true
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    private(set) var selection: LyricsSpot?
    private var hovered: LyricsSpot?
    private var held: LyricsSpot?
    private var layers: [LyricsSpot: LyricsSpotLayer] = [:]
    private var elements: [LyricsSpotElement] = []

    override var isFlipped: Bool {
        true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.width, height: Self.height)
    }

    private var accent: CGColor {
        var colour = NSColor.controlAccentColor.cgColor
        effectiveAppearance.performAsCurrentDrawingAppearance {
            colour = NSColor.controlAccentColor.cgColor
        }
        return colour
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = Self.radius
        layer?.cornerCurve = .continuous
        buildScene()
        for spot in LyricsSpot.all {
            guard let frame = Self.frames[spot] else { continue }
            let spotLayer = LyricsSpotLayer(spot, frame: frame)
            layers[spot] = spotLayer
            layer?.addSublayer(spotLayer)
            elements.append(LyricsSpotElement(spot, frame: frame, parent: self))
        }
        for element in elements {
            element.onPress = { [weak self] spot in self?.pick(spot) }
        }
        restyle(animated: false)
        setAccessibilityElement(true)
        setAccessibilityRole(.radioGroup)
        setAccessibilityLabel("Lyrics position")
        setAccessibilityChildren(elements)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        restyle(animated: false)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways],
                owner: self))
    }

    override func resetCursorRects() {
        guard isEnabled else { return }
        for frame in Self.frames.values {
            addCursorRect(frame.insetBy(dx: -Self.slop, dy: -Self.slop), cursor: .pointingHand)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        hover(spot(at: convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with _: NSEvent) {
        hover(nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let spot = spot(at: convert(event.locationInWindow, from: nil)) else {
            return
        }
        held = spot
        press(spot, down: true)
    }

    override func mouseUp(with event: NSEvent) {
        guard let spot = held else { return }
        held = nil
        press(spot, down: false)
        if self.spot(at: convert(event.locationInWindow, from: nil)) == spot {
            pick(spot)
        }
    }

    func select(_ spot: LyricsSpot?, animated: Bool) {
        guard spot != selection else { return }
        selection = spot
        for element in elements {
            element.setAccessibilityValue(element.spot == spot ? 1 : 0)
        }
        restyle(animated: animated)
        if animated, let spot { pop(spot) }
    }

    func spot(at point: NSPoint) -> LyricsSpot? {
        guard isEnabled else { return nil }
        return LyricsSpot.all.first { spot in
            Self.frames[spot]?.insetBy(dx: -Self.slop, dy: -Self.slop).contains(point) == true
        }
    }

    private func pick(_ spot: LyricsSpot) {
        guard isEnabled, spot != selection else { return }
        select(spot, animated: true)
        onPick?(spot)
    }

    private func hover(_ spot: LyricsSpot?) {
        guard spot != hovered else { return }
        hovered = spot
        restyle(animated: true)
    }

    private func restyle(animated: Bool) {
        let tint = accent
        let seconds = animated && !reducesMotion() ? Self.hoverSeconds : 0
        CATransaction.begin()
        CATransaction.setAnimationDuration(seconds)
        for (spot, badge) in layers {
            badge.apply(state(of: spot), accent: tint)
        }
        CATransaction.commit()
    }

    private func state(of spot: LyricsSpot) -> LyricsSpotLayer.State {
        if spot == selection { return .selected }
        return spot == hovered ? .hover : .idle
    }

    private func press(_ spot: LyricsSpot, down: Bool) {
        guard let badge = layers[spot] else { return }
        let squeeze = CATransform3DMakeScale(Self.pressed, Self.pressed, 1)
        CATransaction.begin()
        CATransaction.setAnimationDuration(reducesMotion() ? 0 : Self.hoverSeconds)
        badge.transform = down ? squeeze : CATransform3DIdentity
        CATransaction.commit()
    }

    private func pop(_ spot: LyricsSpot) {
        guard !reducesMotion(), let badge = layers[spot] else { return }
        let bounce = CASpringAnimation(keyPath: "transform.scale")
        bounce.fromValue = Self.popFrom
        bounce.toValue = 1
        bounce.damping = Self.damping
        bounce.stiffness = Self.stiffness
        bounce.mass = 1
        bounce.duration = bounce.settlingDuration
        badge.add(bounce, forKey: "pop")
    }
}
