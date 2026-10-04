import AppKit

final class WidgetTile: NSView {
    private typealias Look = (fill: NSColor, edge: NSColor)

    static let radius: CGFloat = 16
    static let horizontal: CGFloat = 12
    private static let trackLeading: CGFloat = 10
    static let vertical: CGFloat = 10
    static let noteSize: CGFloat = 12
    private static let iconSize: CGFloat = 13
    private static let iconGap: CGFloat = 4
    private static let meterGap: CGFloat = 8
    private static let headlineBar = (fraction: 0.4, height: 18.0)
    private static let detailBar = (fraction: 0.7, height: 10.0)
    private static let fillAlpha = (dark: 0.055, light: 0.55)
    private static let edgeAlpha = (dark: 0.07, light: 0.06)
    private static let selectedFillAlpha = (dark: 0.13, light: 0.065)
    private static let selectedEdgeAlpha = (dark: 0.26, light: 0.16)
    private static let editFillAlpha = (dark: 0.07, light: 0.55)
    private static let editEdgeAlpha = (dark: 0.28, light: 0.2)
    private static let liftedAlpha: CGFloat = 0.35
    static let fill = tone(.white, .white, fillAlpha)
    static let edge = tone(.white, .black, edgeAlpha)
    static let selectedFill = tone(.white, .black, selectedFillAlpha)
    static let selectedEdge = tone(.white, .black, selectedEdgeAlpha)
    private static let editFill = tone(.white, .white, editFillAlpha)
    static let editEdge = tone(.white, .black, editEdgeAlpha)
    private static let floatingSelectedAlpha = (dark: 0.34, light: 0.80)
    private static let floatingSelectedTint = (red: 0.55, green: 0.55, blue: 0.63)
    private static let floatingSelectedFill = tone(
        NSColor(
            srgbRed: floatingSelectedTint.red, green: floatingSelectedTint.green,
            blue: floatingSelectedTint.blue, alpha: 1),
        .white, floatingSelectedAlpha)
    private static let inlineLooks: (resting: Look, picked: Look) = (
        (fill, edge), (selectedFill, selectedEdge)
    )
    private static let floatingLooks: (resting: Look, picked: Look) = (
        (.clear, .clear), (floatingSelectedFill, selectedEdge)
    )

    let title = NSTextField(labelWithString: "")
    let value = NSTextField(labelWithString: "")
    let headline = NSTextField(labelWithString: "")
    let skeleton = [headlineBar, detailBar].map { bar in
        WidgetSkeleton(fraction: bar.fraction, height: bar.height)
    }
    let detail = NSTextField(labelWithString: "")
    let span = WidgetSpan()
    let reason = NSTextField(labelWithString: "")
    let allow = AllowCapsule()
    let icon = NSImageView()
    let meters = NSStackView()
    let track = WidgetTrack()
    private lazy var trackPlacement = [
        track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.trackLeading),
        track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
        track.centerYAnchor.constraint(equalTo: centerYAnchor),
    ]
    private let box = NSBox()
    let lines = NSStackView()
    let request = NSStackView()
    let dash = DashedOutline(colour: WidgetTile.editEdge, width: 1, fill: .clear)
    let remove = RemoveBadge()
    let grip = Grip(colour: .tertiaryLabelColor)
    let floating: Bool
    private let looks: (resting: Look, picked: Look)
    private(set) var widgetID = ""
    private var hasTrack = false
    var dragStart: NSEvent?
    var compact = false
    var onPress: (() -> Void)?
    var onSkip: ((WidgetGrid.Skip) -> Void)?
    var onRemove: (() -> Void)?
    var onDrag: ((String?, NSPoint, Any?) -> NSDragOperation)?
    var onDrop: ((String?) -> Bool)?
    var onDragEnd: (() -> Void)?

    var selected = false {
        didSet { paint() }
    }

    var editing = false {
        didSet {
            showEditing()
            paint()
            setAccessibilityCustomActions(customActions())
        }
    }

    var lifted = false {
        didSet { alphaValue = lifted ? Self.liftedAlpha : 1 }
    }

    init(floating: Bool) {
        self.floating = floating
        looks = floating ? Self.floatingLooks : Self.inlineLooks
        super.init(frame: .zero)
        box.boxType = .custom
        box.cornerRadius = Self.radius
        box.borderWidth = 1
        paint()
        box.autoresizingMask = [.width, .height]
        addSubview(box)
        arrangeLines()
        arrangeEditing()
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        meters.orientation = .vertical
        meters.spacing = Self.meterGap
        meters.translatesAutoresizingMaskIntoConstraints = false
        [meters, track].forEach(addSubview)
        NSLayoutConstraint.activate([
            meters.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            meters.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            meters.centerYAnchor.constraint(equalTo: centerYAnchor),
            value.trailingAnchor.constraint(
                lessThanOrEqualTo: icon.leadingAnchor, constant: -Self.iconGap),
            icon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            icon.centerYAnchor.constraint(equalTo: value.centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func tone(
        _ dark: NSColor, _ light: NSColor, _ alpha: (dark: Double, light: Double)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark.withAlphaComponent(alpha.dark) : light.withAlphaComponent(alpha.light)
        }
    }

    private func paint() {
        let look = selected ? looks.picked : looks.resting
        if editing {
            box.fillColor = selected ? Self.selectedFill : Self.editFill
            box.borderColor = .clear
        } else {
            box.fillColor = look.fill
            box.borderColor = look.edge
        }
        setAccessibilitySelected(selected)
    }

    func show(_ widget: WidgetGrid.Widget) {
        widgetID = widget.id
        hasTrack = widget.track != nil
        var readings: [WidgetGrid.Meter] = []
        var symbol: String?
        switch widget.content {
        case let .value(_, _, name, _): symbol = name
        case let .meters(list): readings = list
        case let .track(playing): track.show(playing)
        case .loading, .notice, .permission, .unavailable: break
        }
        let visible = showLines(of: widget.content)
        for row in lines.arrangedSubviews {
            row.isHidden = !visible.contains(row)
        }
        icon.image = symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        showMeters(readings)
        showTrack(widget.track != nil)
        setAccessibilityLabel(widget.spoken)
        setAccessibilityCustomActions(customActions())
    }

    private func customActions() -> [NSAccessibilityCustomAction] {
        if editing {
            return [
                NSAccessibilityCustomAction(name: "Remove") { [weak self] in
                    self?.onRemove?()
                    return true
                }
            ]
        }
        return hasTrack ? [skip("Previous Track", .previous), skip("Next Track", .next)] : []
    }

    private func showTrack(_ shows: Bool) {
        track.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(trackPlacement)
        } else {
            NSLayoutConstraint.deactivate(trackPlacement)
        }
    }

    private func skip(_ name: String, _ skip: WidgetGrid.Skip) -> NSAccessibilityCustomAction {
        NSAccessibilityCustomAction(name: name) { [weak self] in
            self?.onSkip?(skip)
            return true
        }
    }

    private func showMeters(_ readings: [WidgetGrid.Meter]) {
        if meters.arrangedSubviews.count != readings.count {
            meters.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for _ in readings {
                let meter = WidgetMeter()
                meters.addArrangedSubview(meter)
                meter.widthAnchor.constraint(equalTo: meters.widthAnchor).isActive = true
            }
        }
        for (view, meter) in zip(meters.arrangedSubviews, readings) {
            (view as? WidgetMeter)?.show(meter)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: unsafe superview)
        return bounds.contains(local) || (editing && remove.frame.contains(local)) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        if editing {
            pressWhileEditing(event)
            return
        }
        if event.modifierFlags.contains(.command) {
            dragStart = event
            return
        }
        let point = track.convert(event.locationInWindow, from: nil)
        if !track.isHidden, let skip = track.skip(at: point) {
            onSkip?(skip)
        } else {
            onPress?()
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard dragStart != nil, unsafe window != nil else { return }
        dragStart = nil
        beginDrag(with: event)
    }

    override func mouseUp(with _: NSEvent) {
        dragStart = nil
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard let window = unsafe window else { return [] }
        return onDrag?(
            sender.draggingPasteboard.string(forType: WidgetGrid.dragType),
            window.convertPoint(toScreen: sender.draggingLocation), sender.draggingSource) ?? []
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDrop?(sender.draggingPasteboard.string(forType: WidgetGrid.dragType)) ?? false
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}
