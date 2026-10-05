import AppKit

final class WidgetTile: NSView {
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
    let month = WidgetMonth()
    let countdown = NSTextField(labelWithString: "")
    private lazy var trackPlacement = [
        track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.trackLeading),
        track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
        track.centerYAnchor.constraint(equalTo: centerYAnchor),
    ]
    private let box = NSBox()
    let lines = NSStackView()
    let request = NSStackView()
    let dash = DashedOutline(colour: WidgetTile.editEdge, width: 1, fill: .clear)
    let slot = WidgetTile.makeSlot()
    let remove = RemoveBadge()
    let grip = Grip(colour: .tertiaryLabelColor)
    let resizer = WidgetResizeHandle()
    let floating: Bool
    private let looks: (resting: Look, picked: Look)
    private(set) var widgetID = ""
    private var hasTrack = false
    var dragStart: NSEvent?
    var resizeStart: CGFloat?
    var compact = false
    var onPress: (() -> Void)?
    var onExtend: (() -> Void)?
    var onSkip: ((WidgetGrid.Skip) -> Void)?
    var onRemove: (() -> Void)?
    var onResize: ((Resize) -> Void)?
    var onDrag: ((String?, NSPoint, Any?) -> NSDragOperation)?
    var onDrop: ((String?) -> Bool)?
    var onDragStart: (() -> Void)?
    var onDragEnd: (() -> Void)?

    var selected = false {
        didSet {
            paint()
            showGrip()
        }
    }

    var editing = false {
        didSet {
            showEditing()
            paint()
        }
    }

    var lifted = false {
        didSet { showLifted() }
    }

    var resizable = false {
        didSet { showEditing() }
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
        arrangeCalendar()
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
        case .month, .event, .loading, .notice, .permission, .unavailable: break
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

    func customActions() -> [NSAccessibilityCustomAction] {
        if editing { return editingActions() }
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
            dragStart = beginResize(event) ? nil : event
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
        if let resizeStart {
            onResize?(.drag(screenX(of: event) - resizeStart))
            return
        }
        guard let start = dragStart, unsafe window != nil else { return }
        dragStart = nil
        beginDrag(with: start)
    }

    override func mouseUp(with _: NSEvent) {
        dragStart = nil
        if resizeStart != nil {
            resizeStart = nil
            onResize?(.drop)
        }
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
