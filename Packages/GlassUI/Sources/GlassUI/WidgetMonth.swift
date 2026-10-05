import AppCore
import AppKit

final class WidgetMonth: NSView {
    enum Hit: Equatable {
        case day(Int)
        case page(WidgetGrid.Page)
    }

    private static let controlGap: CGFloat = 4
    private static let reach: CGFloat = 2
    private static let swipe: CGFloat = 36
    private static let travel: CGFloat = 14
    private static let slide: CFTimeInterval = 0.26
    private static let fade: CFTimeInterval = 0.16
    private static let slideStart = (x: 0.2, y: 0.8)
    private static let slideEnd = (x: 0.2, y: 1.0)

    private(set) var month: AgendaMonth?
    private var shown: WidgetGrid.Month?
    private var page = WidgetMonthPage()
    private let previous = WidgetMonthControl(.symbol("chevron.left"))
    private let next = WidgetMonthControl(.symbol("chevron.right"))
    private let today = WidgetMonthControl(.label("Today"))
    private var pointerInside = false
    private var hovered: Hit?
    private var travelled: CGFloat = 0
    private var locked = false
    var onDay: ((String) -> Void)?
    var onPage: ((WidgetGrid.Page) -> Void)?

    var isInteractive = false {
        didSet {
            guard isInteractive != oldValue else { return }
            if !isInteractive { hover(nil) }
            showControls()
            needsLayout = true
        }
    }

    override var isFlipped: Bool { true }

    private var animates: Bool {
        unsafe window?.isVisible == true
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        for view in [page, previous, next, today] {
            addSubview(view)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: .zero,
                options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ next: WidgetGrid.Month) {
        guard next != shown else { return }
        let before = shown
        shown = next
        guard let grid = next.grid(in: .current) else {
            month = nil
            return
        }
        month = grid
        if let before, before.shift != next.shift, animates {
            turn(to: grid, colours: next.colours, towards: next.shift > before.shift ? 1 : -1)
        } else {
            page.show(grid, colours: next.colours)
        }
        showControls()
        refreshHover()
    }

    func accessibilityActions() -> [NSAccessibilityCustomAction] {
        guard isInteractive else { return [] }
        let actions =
            [("Previous Month", WidgetGrid.Page.previous), ("Next Month", .next)]
            + ((shown?.shift ?? 0) == 0 ? [] : [("Today", .today)])
        return actions.map { name, target in
            NSAccessibilityCustomAction(name: name) { [weak self] in
                self?.onPage?(target)
                return true
            }
        }
    }

    override func layout() {
        super.layout()
        var right = bounds.maxX
        for control in [next, previous, today] {
            control.frame = NSRect(
                x: right - control.width, y: 0, width: control.width,
                height: WidgetMonthControl.height)
            right -= control.width + Self.controlGap
        }
        page.reserved = isInteractive ? bounds.maxX - right : 0
    }

    func hit(at point: NSPoint) -> Hit? {
        guard isInteractive, !isHidden else { return nil }
        let inset = -Self.reach
        let controls = [(today, WidgetGrid.Page.today), (previous, .previous), (next, .next)]
        for (control, target) in controls
        where control.isShown && control.frame.insetBy(dx: inset, dy: inset).contains(point) {
            return .page(target)
        }
        guard shown?.opensDays == true else { return nil }
        return page.index(at: convert(point, to: page)).map(Hit.day)
    }

    func press(_ hit: Hit) {
        switch hit {
        case .page(let target):
            onPage?(target)

        case .day(let index):
            if let day = month?.days[index] { onDay?(day.query) }
        }
    }

    func scroll(_ event: NSEvent) {
        guard event.momentumPhase.isEmpty else { return }
        if event.phase.contains(.began) {
            travelled = 0
            locked = false
        }
        defer {
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                travelled = 0
                locked = false
            }
        }
        let delta =
            abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
            ? event.scrollingDeltaX : event.scrollingDeltaY
        guard !locked else { return }
        travelled += delta
        guard abs(travelled) > (event.hasPreciseScrollingDeltas ? Self.swipe : 0) else { return }
        let target: WidgetGrid.Page = travelled < 0 ? .next : .previous
        travelled = 0
        locked = !event.phase.isEmpty
        onPage?(target)
    }

    override func mouseMoved(with _: NSEvent) {
        track()
    }

    override func mouseEntered(with _: NSEvent) {
        track()
    }

    override func mouseExited(with _: NSEvent) {
        pointerInside = false
        hover(nil)
        showControls()
    }

    private func track() {
        pointerInside = true
        showControls()
        refreshHover()
    }

    private func refreshHover() {
        guard isInteractive, pointerInside, let window = unsafe window else { return }
        hover(hit(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)))
    }

    private func hover(_ hit: Hit?) {
        guard hit != hovered else { return }
        hovered = hit
        if case .day(let index) = hit {
            page.hovered = index
        } else {
            page.hovered = nil
        }
        previous.isHovered = hit == .page(.previous)
        next.isHovered = hit == .page(.next)
        today.isHovered = hit == .page(.today)
    }

    private func showControls() {
        let arrows = isInteractive && pointerInside
        let pill = isInteractive && (shown?.shift ?? 0) != 0
        let wanted = [(previous, arrows), (next, arrows), (today, pill)]
        for (control, visible) in wanted where control.isShown != visible {
            control.isShown = visible
            if animates {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = Self.fade
                    control.animator().alphaValue = visible ? 1 : 0
                }
            } else {
                control.alphaValue = visible ? 1 : 0
            }
        }
    }

    private func turn(to grid: AgendaMonth, colours: [String: NSColor], towards way: CGFloat) {
        let old = page
        let new = WidgetMonthPage()
        new.show(grid, colours: colours)
        new.reserved = old.reserved
        new.frame = bounds.offsetBy(dx: Self.travel * way, dy: 0)
        new.alphaValue = 0
        addSubview(new, positioned: .below, relativeTo: old)
        page = new
        old.hovered = nil
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = Self.slide
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: Float(Self.slideStart.x), Float(Self.slideStart.y),
                    Float(Self.slideEnd.x), Float(Self.slideEnd.y))
                new.animator().frame = bounds
                new.animator().alphaValue = 1
                old.animator().frame = bounds.offsetBy(dx: -Self.travel * way, dy: 0)
                old.animator().alphaValue = 0
            },
            completionHandler: { MainActor.assumeIsolated { old.removeFromSuperview() } })
    }
}
