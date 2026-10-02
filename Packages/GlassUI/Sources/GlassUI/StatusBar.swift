public import AppKit

public final class StatusBar: NSScrollView {
    public struct Pill: Sendable, Equatable {
        public let id: String
        public let name: String
        public let symbol: String
        public let value: String
        public let unit: String
        public let action: String

        var spoken: String {
            unit.isEmpty ? "\(name): \(value)" : "\(name): \(value) \(unit)"
        }

        public init(
            id: String, name: String, symbol: String, value: String, action: String,
            unit: String = ""
        ) {
            self.id = id
            self.name = name
            self.symbol = symbol
            self.value = value
            self.unit = unit
            self.action = action
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
    private static let ease = CAMediaTimingFunction(
        controlPoints: Float(curveStart.x), Float(curveStart.y), Float(curveEnd.x),
        Float(curveEnd.y))

    var pills: [Pill] = [] {
        didSet {
            guard pills != oldValue else { return }
            if pills.map(\.id) == oldValue.map(\.id) {
                zip(pills, views).forEach(show)
                return
            }
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for (index, pill) in pills.enumerated() {
                stack.addArrangedSubview(makeView(for: pill, at: index))
            }
        }
    }

    var onPress: ((Int) -> Void)?
    let edges = CAGradientLayer()
    private let stack = NSStackView()
    private var followsSelection = false
    private var heading: NSPoint?
    private var shadedAt: CGFloat?
    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    var views: [StatusPill] {
        stack.arrangedSubviews.compactMap { $0 as? StatusPill }
    }

    init() {
        super.init(frame: .zero)
        stack.spacing = Self.gap
        stack.edgeInsets = NSEdgeInsets(top: 0, left: Self.edge, bottom: 0, right: Self.edge)
        stack.translatesAutoresizingMaskIntoConstraints = false
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
        for (position, view) in views.enumerated() {
            if position == index, !view.selected {
                followsSelection = true
            }
            view.selected = position == index
        }
        settle()
    }

    private func settle() {
        if followsSelection, let selected = views.first(where: \.selected) {
            reveal(selected.frame.insetBy(dx: -Self.fade, dy: 0))
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

    private func makeView(for pill: Pill, at index: Int) -> StatusPill {
        let view = StatusPill()
        view.onPress = { [weak self] in self?.onPress?(index) }
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        show(pill, in: view)
        return view
    }

    private func show(_ pill: Pill, in view: StatusPill) {
        let unit = pill.unit.isEmpty ? "" : " \(pill.unit)"
        view.show(StatusPill.styled(bold: pill.value, rest: unit), symbol: pill.symbol)
        view.setAccessibilityLabel(pill.spoken)
    }
}
