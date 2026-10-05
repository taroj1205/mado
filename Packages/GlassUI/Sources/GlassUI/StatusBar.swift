public import AppKit

public final class StatusBar: NSScrollView {
    public struct Pill: Sendable, Equatable {
        public let id: String
        public let name: String
        public let symbol: String
        public let value: String
        public let unit: String
        public let action: String
        public let shownByDefault: Bool

        var reading: String {
            unit.isEmpty ? value : "\(value) \(unit)"
        }

        var spoken: String {
            "\(name): \(reading)"
        }

        public init(
            id: String, name: String, symbol: String, value: String, action: String,
            unit: String = "", shownByDefault: Bool = true
        ) {
            self.id = id
            self.name = name
            self.symbol = symbol
            self.value = value
            self.unit = unit
            self.action = action
            self.shownByDefault = shownByDefault
        }
    }

    static let height: CGFloat = 60
    private static let gap: CGFloat = 6
    private static let edge: CGFloat = 2
    private static let fade: CGFloat = 28
    private static let middle = 0.5
    private static let glide: TimeInterval = 0.28
    private static let blend = "colors"
    private static let curveStart = (x: 0.2, y: 0.8)
    private static let curveEnd = (x: 0.2, y: 1.0)
    static let ease = CAMediaTimingFunction(
        controlPoints: Float(curveStart.x), Float(curveStart.y), Float(curveEnd.x),
        Float(curveEnd.y))

    var pills: [Pill] = [] {
        didSet {
            guard pills != oldValue else { return }
            if !holdsMouse() {
                dragStart = []
            }
            if dragStart.isEmpty, shownIDs != pills.map(\.id) {
                rebuild()
                return
            }
            for view in views {
                if let pill = pills.first(where: { $0.id == view.identifier?.rawValue }) {
                    show(pill, in: view)
                }
            }
        }
    }

    var onPress: ((Int) -> Void)?
    var onMove: ((String, String?) -> Void)?
    let edges = CAGradientLayer()
    let customise = CustomiseButton()
    let stack = NSStackView()
    private var followsSelection = false
    var dragStart: [String] = []
    private var heading: NSPoint?
    private var shadedAt: CGFloat?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var holdsMouse = { NSEvent.pressedMouseButtons != 0 }

    var views: [StatusPill] {
        stack.arrangedSubviews.compactMap { $0 as? StatusPill }
    }

    var shownIDs: [String] {
        views.compactMap(\.identifier?.rawValue)
    }

    init() {
        super.init(frame: .zero)
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.edge, bottom: 0, right: Self.edge)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(customise)
        documentView = stack
        drawsBackground = false
        hasHorizontalScroller = false
        verticalScrollElasticity = .none
        translatesAutoresizingMaskIntoConstraints = false
        let fit = widthAnchor.constraint(equalTo: stack.widthAnchor)
        fit.priority = .defaultLow
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            fit,
        ])
        wantsLayer = true
        edges.startPoint = CGPoint(x: 0, y: Self.middle)
        edges.endPoint = CGPoint(x: 1, y: Self.middle)
        layer?.mask = edges
        setAccessibilityRole(.group)
        setAccessibilityLabel("Status widgets")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func reflectScrolledClipView(_ clipView: NSClipView) {
        super.reflectScrolledClipView(clipView)
        settle()
    }

    override public func scrollWheel(with event: NSEvent) {
        followsSelection = false
        if heading != nil {
            heading = nil
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                contentView.animator().setBoundsOrigin(contentView.bounds.origin)
            }
        }
        super.scrollWheel(with: event)
    }

    func highlight(_ index: Int?) {
        let id = index.flatMap { pills.indices.contains($0) ? pills[$0].id : nil }
        for view in views {
            let selected = id != nil && view.identifier?.rawValue == id
            if selected, !view.selected {
                followsSelection = true
            }
            view.selected = selected
        }
        settle()
    }

    private func settle() {
        if followsSelection, let selected = views.first(where: \.selected) {
            let frame =
                selected === views.last ? selected.frame.union(customise.frame) : selected.frame
            reveal(frame.insetBy(dx: -Self.fade, dy: 0))
        }
        shade()
    }

    private func shade() {
        let visible = documentVisibleRect
        let stop = min(Double(Self.fade / max(bounds.width, 1)), Self.middle)
        let opaque = NSColor.black.cgColor
        let colors = [
            edge(hiding: visible.minX - stack.frame.minX), opaque, opaque,
            edge(hiding: stack.frame.maxX - visible.maxX),
        ]
        let shown = (edges.presentation() ?? edges).colors as? [CGColor]
        let scrolled = visible.minX != shadedAt
        shadedAt = visible.minX
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        edges.frame = bounds
        edges.locations = [0, stop, 1 - stop, 1].map { .init(value: $0) }
        if scrolled || reducesMotion() {
            edges.removeAnimation(forKey: Self.blend)
        } else if shown != colors {
            let animation = CABasicAnimation(keyPath: Self.blend)
            animation.fromValue = shown
            animation.duration = Self.glide
            animation.timingFunction = Self.ease
            edges.add(animation, forKey: Self.blend)
        }
        edges.colors = colors
        CATransaction.commit()
    }

    private func edge(hiding overflow: CGFloat) -> CGColor {
        NSColor.black.withAlphaComponent(1 - min(max(overflow / Self.fade, 0), 1)).cgColor
    }

    private func reveal(_ rect: NSRect) {
        let from = heading ?? documentVisibleRect.origin
        var target = NSRect(origin: from, size: documentVisibleRect.size)
        if rect.minX < target.minX {
            target.origin.x = rect.minX
        } else if rect.maxX > target.maxX {
            target.origin.x = rect.maxX - target.width
        }
        let origin = contentView.constrainBoundsRect(target).origin
        guard origin != from else { return }
        guard !reducesMotion() else {
            heading = nil
            contentView.setBoundsOrigin(origin)
            return
        }
        heading = origin
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.glide
            context.timingFunction = Self.ease
            contentView.animator().setBoundsOrigin(origin)
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                if self?.heading == origin { self?.heading = nil }
            }
        }
    }

    private func makeView(for pill: Pill) -> StatusPill {
        let view = StatusPill()
        view.identifier = NSUserInterfaceItemIdentifier(pill.id)
        view.onPress = { [weak self] in
            guard let self, let index = pills.firstIndex(where: { $0.id == pill.id }) else {
                return
            }
            onPress?(index)
        }
        view.onGrab = { [weak self] in self?.grab() }
        view.onDrag = { [weak self, weak view] point in
            if let view { self?.drag(view, to: point) }
        }
        view.onDrop = { [weak self] in self?.drop(pill.id) }
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        show(pill, in: view)
        return view
    }

    func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for pill in pills {
            stack.addArrangedSubview(makeView(for: pill))
        }
        stack.addArrangedSubview(customise)
    }

    private func show(_ pill: Pill, in view: StatusPill) {
        let unit = pill.unit.isEmpty ? "" : " \(pill.unit)"
        view.show(StatusPill.styled(bold: pill.value, rest: unit), symbol: pill.symbol)
        view.setAccessibilityLabel(pill.spoken)
    }
}
