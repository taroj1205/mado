import AppKit

final class WidgetTile: NSView {
    static let radius: CGFloat = 16
    static let horizontal: CGFloat = 12
    static let vertical: CGFloat = 10
    static let noteSize: CGFloat = 12
    static let delays = (hover: 0.3, hold: 0.5)
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
    let verse = WidgetLyrics()
    let face = WidgetFace()
    let wash = WidgetWash()
    let month = WidgetMonth()
    let countdown = NSTextField(labelWithString: "")
    lazy var trackPlacement = trackConstraints()
    lazy var versePlacement = verseConstraints()
    let box = NSBox()
    let lines = NSStackView()
    let request = NSStackView()
    let dash = DashedOutline(
        colour: WidgetTile.editEdge, width: 1, fill: .clear, radius: WidgetTile.radius)
    let slot = DashedOutline.slot(radius: WidgetTile.radius)
    let remove = RemoveBadge()
    let grip = Grip(colour: .tertiaryLabelColor)
    let resizer = WidgetResizeHandle()
    let more = WidgetMoreButton()
    let hoverDelay = Delay(seconds: WidgetTile.delays.hover)
    let holdDelay = Delay(seconds: WidgetTile.delays.hold)
    let floating: Bool
    let looks: (resting: Look, picked: Look)
    var widgetID = ""
    var widget: WidgetGrid.Widget?
    var form = WidgetForm(size: .zero)
    var dragStart: NSEvent?
    var holdOrigin: NSPoint?
    var resizeStart: NSPoint?
    var compact = false
    var onPress: (() -> Void)?
    var onOpen: (() -> Void)?
    var onMenu: ((NSPoint) -> Void)?
    var onHold: ((NSPoint) -> Void)?
    var opensOnSingleClick = false
    var onExtend: (() -> Void)?
    var onSkip: ((WidgetGrid.Skip) -> Void)?
    var onPlay: (() -> Void)?
    var onSeek: ((Int) -> Void)?
    var onDay: ((String) -> Void)?
    var onPage: ((WidgetGrid.Page) -> Void)?
    var onRemove: (() -> Void)?
    var onResize: ((Resize) -> Void)?
    var onDrag: ((String?, NSPoint, Any?) -> NSDragOperation)?
    var onDrop: ((String?) -> Bool)?
    var onDragStart: (() -> Void)?
    var onDragOff: ((String, NSPoint) -> Void)?
    var onDragEnd: (() -> Void)?

    var selected = false {
        didSet {
            paint()
            showGrip()
        }
    }

    var hovering = false {
        didSet { showMore() }
    }

    var menuOpen = false {
        didSet { showMore() }
    }

    var editing = false {
        didSet {
            showEditing()
            showMore()
            wash.alphaValue = editing ? 0 : 1
            paint()
        }
    }

    var lifted = false {
        didSet { showLifted() }
    }

    var resizes: Set<Axis> = [] {
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
        wash.frame = bounds
        wash.autoresizingMask = [.width, .height]
        addSubview(wash)
        face.autoresizingMask = [.width, .height]
        face.isHidden = true
        addSubview(face)
        arrangeLines()
        arrangeCalendar()
        arrangeEditing()
        arrangeMore()
        month.onDay = { [weak self] query in self?.onDay?(query) }
        month.onPage = { [weak self] page in self?.onPage?(page) }
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        meters.orientation = .vertical
        meters.spacing = Self.meterGap
        meters.translatesAutoresizingMaskIntoConstraints = false
        [meters, track, verse].forEach(addSubview)
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

    override func layout() {
        super.layout()
        dash.frame = bounds
        slot.frame = bounds
        more.frame = moreFrame
        let next = WidgetForm(size: bounds.size)
        if next != form {
            form = next
            showFace()
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
        if event.modifierFlags.contains(.control) || pressesMore(event) {
            onMenu?(menuAnchor(for: event))
            return
        }
        let point = track.convert(event.locationInWindow, from: nil)
        if !track.isHidden, let skip = track.skip(at: point) {
            onSkip?(skip)
        } else if !track.isHidden, track.pressesDisc(at: point) {
            onPlay?()
        } else if let line = lyricLine(at: event) {
            onSeek?(line)
        } else if let hit = month.hit(at: month.convert(event.locationInWindow, from: nil)) {
            month.press(hit)
        } else {
            onPress?()
            openIfAsked(by: event)
            startHold(with: event)
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        if editing {
            super.rightMouseDown(with: event)
        } else {
            onMenu?(menuAnchor(for: event))
        }
    }

    override func mouseEntered(with _: NSEvent) {
        hoverDelay.start { [weak self] in self?.hovering = true }
    }

    override func mouseExited(with _: NSEvent) {
        hoverDelay.cancel()
        hovering = false
    }

    override func scrollWheel(with event: NSEvent) {
        if month.isInteractive, !month.isHidden {
            month.scroll(event)
        } else {
            super.scrollWheel(with: event)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        cancelHold(ifMovedBy: event)
        if let resizeStart {
            let point = screenPoint(of: event)
            onResize?(
                .drag(CGSize(width: point.x - resizeStart.x, height: resizeStart.y - point.y)))
            return
        }
        guard let start = dragStart, unsafe window != nil else { return }
        dragStart = nil
        beginDrag(with: start, grabbedAt: nil)
    }

    override func mouseUp(with _: NSEvent) {
        holdDelay.cancel()
        holdOrigin = nil
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

    override func accessibilityPerformShowMenu() -> Bool {
        guard !editing, let onMenu else { return false }
        onMenu(buttonAnchor)
        return true
    }

    override func accessibilityPerformPress() -> Bool {
        pressForAccessibility()
        return true
    }
}
