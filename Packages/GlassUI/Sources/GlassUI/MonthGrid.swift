import AppCore
import AppKit

final class MonthGrid: NSView {
    private final class Face: NSView {
        var drawing: (() -> Void)?

        override var isFlipped: Bool { true }

        override func draw(_: NSRect) {
            drawing?()
        }
    }

    private final class Highlight: NSView {
        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            layer?.cornerRadius = bounds.height * MonthGrid.half
        }
    }

    private final class DayElement: NSAccessibilityElement {
        var onPress: (() -> Void)?

        override func accessibilityPerformPress() -> Bool {
            onPress?()
            return true
        }
    }

    static let half: CGFloat = 0.5
    private static let columns = 7
    private static let headerHeight: CGFloat = 18
    private static let headerGap: CGFloat = 4
    private static let cellHeight: CGFloat = 34
    private static let circle: CGFloat = 26
    private static let circleTop: CGFloat = 1
    private static let dot: CGFloat = 4
    private static let dotGap: CGFloat = 3
    private static let dotTop: CGFloat = 29
    private static let maxDots = 3
    private static let numberSize: CGFloat = 13
    private static let weekdaySize: CGFloat = 10
    private static let weekdayKern: CGFloat = 0.4
    private static let todayRing: CGFloat = 1.5
    private static let todayRingAlpha: CGFloat = 0.55
    private static let outsideDotAlpha: CGFloat = 0.4
    private static let hoverAlpha: CGFloat = 0.1
    private static let slide: CFTimeInterval = 0.24
    private static let slideStart = (x: 0.2, y: 0.8)
    private static let slideEnd = (x: 0.2, y: 1.0)

    var onPick: ((String) -> Void)?
    private(set) var month: LauncherView.CalendarMonth?
    private let face = Face()
    private let highlight = Highlight()
    private var elements: [DayElement] = []
    private var hovered: Int?

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        let rows = (month?.month.days.count ?? 0) / Self.columns
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: Self.headerHeight + Self.headerGap + CGFloat(rows) * Self.cellHeight)
    }

    private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    override init(frame: NSRect) {
        super.init(frame: frame)
        highlight.isHidden = true
        face.drawing = { [weak self] in self?.drawFace() }
        for view in [highlight, face] {
            addSubview(view)
        }
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
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

    private static func text(
        _ string: String, size: CGFloat, weight: NSFont.Weight, colour: NSColor, kern: CGFloat = 0
    ) -> NSAttributedString {
        NSAttributedString(
            string: string,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight),
                .foregroundColor: colour, .kern: kern,
            ])
    }

    private static func draw(_ text: NSAttributedString, centredIn rect: NSRect) {
        let size = text.size()
        text.draw(
            at: NSPoint(
                x: rect.midX - size.width * half, y: rect.midY - size.height * half))
    }

    func show(_ next: LauncherView.CalendarMonth) {
        let slides =
            !highlight.isHidden && month?.month.days.first?.start == next.month.days.first?.start
        month = next
        hovered = nil
        setAccessibilityLabel("\(next.month.name) \(next.month.year)")
        elements = next.month.days.enumerated().map { index, day in
            let element = DayElement()
            element.setAccessibilityRole(.button)
            element.setAccessibilityLabel(day.label)
            element.setAccessibilityParent(self)
            element.setAccessibilitySelected(index == next.month.focused)
            element.onPress = { [weak self] in self?.onPick?(day.query) }
            return element
        }
        setAccessibilityChildren(elements)
        invalidateIntrinsicContentSize()
        needsLayout = true
        face.needsDisplay = true
        placeHighlight(animated: slides && animates)
    }

    override func layout() {
        super.layout()
        face.frame = bounds
        for (index, element) in elements.enumerated() {
            element.setAccessibilityFrameInParentSpace(cell(index))
        }
        placeHighlight(animated: false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseMoved(with event: NSEvent) {
        hover(index(at: event))
    }

    override func mouseExited(with _: NSEvent) {
        hover(nil)
    }

    override func mouseDown(with event: NSEvent) {
        guard let index = index(at: event), let day = month?.month.days[index] else { return }
        onPick?(day.query)
    }

    private func hover(_ index: Int?) {
        guard index != hovered else { return }
        hovered = index
        face.needsDisplay = true
    }

    private func index(at event: NSEvent) -> Int? {
        let point = convert(event.locationInWindow, from: nil)
        let count = month?.month.days.count ?? 0
        return (0..<count).first { cell($0).contains(point) }
    }

    private func cell(_ index: Int) -> NSRect {
        let width = bounds.width / CGFloat(Self.columns)
        let row = index / Self.columns
        let column = index % Self.columns
        return NSRect(
            x: CGFloat(column) * width,
            y: Self.headerHeight + Self.headerGap + CGFloat(row) * Self.cellHeight,
            width: width, height: Self.cellHeight)
    }

    private func circle(in cell: NSRect) -> NSRect {
        NSRect(
            x: (cell.midX - Self.circle * Self.half).rounded(), y: cell.minY + Self.circleTop,
            width: Self.circle, height: Self.circle)
    }

    private func placeHighlight(animated: Bool) {
        guard let month, month.month.days.indices.contains(month.month.focused) else {
            highlight.isHidden = true
            return
        }
        let target = circle(in: cell(month.month.focused))
        highlight.isHidden = false
        guard highlight.frame != target else { return }
        guard animated else {
            highlight.frame = target
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.slide
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: Float(Self.slideStart.x), Float(Self.slideStart.y),
                Float(Self.slideEnd.x), Float(Self.slideEnd.y))
            highlight.animator().frame = target
        }
    }

    private func drawFace() {
        guard let month else { return }
        let width = bounds.width / CGFloat(Self.columns)
        for (column, weekday) in month.month.weekdays.enumerated() {
            let rect = NSRect(
                x: CGFloat(column) * width, y: 0, width: width, height: Self.headerHeight)
            Self.draw(
                Self.text(
                    weekday.uppercased(), size: Self.weekdaySize, weight: .semibold,
                    colour: .tertiaryLabelColor, kern: Self.weekdayKern),
                centredIn: rect)
        }
        for index in month.month.days.indices {
            drawDay(index, of: month)
        }
    }

    private func drawDay(_ index: Int, of shown: LauncherView.CalendarMonth) {
        let day = shown.month.days[index]
        let focused = index == shown.month.focused
        let ring = circle(in: cell(index))
        if index == hovered, !focused {
            NSColor.labelColor.withAlphaComponent(Self.hoverAlpha).setFill()
            NSBezierPath(ovalIn: ring).fill()
        }
        if day.isToday, !focused {
            let stroke = NSBezierPath(
                ovalIn: ring.insetBy(dx: Self.todayRing * Self.half, dy: Self.todayRing * Self.half)
            )
            stroke.lineWidth = Self.todayRing
            NSColor.controlAccentColor.withAlphaComponent(Self.todayRingAlpha).setStroke()
            stroke.stroke()
        }
        let colour: NSColor =
            if focused {
                .white
            } else if day.isToday {
                .controlAccentColor
            } else if !day.isInMonth {
                .tertiaryLabelColor
            } else if day.isWeekend {
                .secondaryLabelColor
            } else {
                .labelColor
            }
        let weight: NSFont.Weight = focused || day.isToday ? .semibold : .regular
        Self.draw(
            Self.text(day.number, size: Self.numberSize, weight: weight, colour: colour),
            centredIn: ring)
        drawDots(for: day, in: cell(index), colours: shown.colours)
    }

    private func drawDots(for day: AgendaMonth.Day, in cell: NSRect, colours: [String: NSColor]) {
        let shown = day.events.prefix(Self.maxDots).map { colours[$0.id] ?? .controlAccentColor }
        let width = CGFloat(shown.count) * Self.dot + CGFloat(max(shown.count - 1, 0)) * Self.dotGap
        var left = cell.midX - width * Self.half
        for colour in shown {
            colour.withAlphaComponent(day.isInMonth ? 1 : Self.outsideDotAlpha).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: left, y: cell.minY + Self.dotTop, width: Self.dot, height: Self.dot)
            )
            .fill()
            left += Self.dot + Self.dotGap
        }
    }
}
