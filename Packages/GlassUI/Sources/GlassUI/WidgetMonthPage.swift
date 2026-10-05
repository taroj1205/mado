import AppCore
import AppKit

final class WidgetMonthPage: NSView {
    private struct Metrics {
        let column: CGFloat
        let top: CGFloat
        let row: CGFloat
    }

    private static let titleSize: CGFloat = 11
    private static let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .semibold)
    private static let titleKern: CGFloat = 0.4
    private static let weekdaySize: CGFloat = 9.5
    private static let daySize: CGFloat = 11
    private static let gap: CGFloat = 6
    private static let rowHeight: CGFloat = 20
    private static let markSize: CGFloat = 18
    private static let markInset: CGFloat = 1
    private static let dot: CGFloat = 2.5
    private static let dotGap: CGFloat = 1.5
    private static let dotDrop: CGFloat = 0.5
    private static let maxDots = 3
    private static let outsideDotAlpha: CGFloat = 0.4
    private static let half: CGFloat = 0.5
    private static let hoverAlpha: CGFloat = 0.1
    private static let todayShade: CGFloat = 0.11
    private static let todayText = WidgetTile.tone(
        NSColor(white: todayShade, alpha: 1), .white, (dark: 1, light: 1))
    private static let titleHeight = NSAttributedString(
        string: "A", attributes: [.font: titleFont]
    )
    .size().height

    private(set) var grid: AgendaMonth?
    private var colours: [String: NSColor] = [:]
    var reserved: CGFloat = 0 {
        didSet {
            if reserved != oldValue { needsDisplay = true }
        }
    }
    var hovered: Int? {
        didSet {
            if hovered != oldValue { needsDisplay = true }
        }
    }

    override var isFlipped: Bool { true }

    private var weekdayHeight: CGFloat {
        weekday("A").size().height
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ next: AgendaMonth, colours: [String: NSColor]) {
        guard next != grid || colours != self.colours else { return }
        grid = next
        self.colours = colours
        needsDisplay = true
    }

    func index(at point: NSPoint) -> Int? {
        guard let grid, !grid.initials.isEmpty, bounds.width > 0 else { return nil }
        let metrics = metrics(of: grid)
        guard metrics.row > 0, point.y >= metrics.top, point.y < bounds.height, point.x >= 0,
            point.x < bounds.width
        else { return nil }
        let row = Int(((point.y - metrics.top) / metrics.row).rounded(.down))
        let column = min(Int((point.x / metrics.column).rounded(.down)), grid.initials.count - 1)
        let index = row * grid.initials.count + column
        return grid.days.indices.contains(index) ? index : nil
    }

    private func metrics(of grid: AgendaMonth) -> Metrics {
        let top = Self.titleHeight + Self.gap + weekdayHeight + Self.gap
        let weeks = (grid.days.count + grid.initials.count - 1) / grid.initials.count
        return Metrics(
            column: bounds.width / CGFloat(grid.initials.count), top: top,
            row: min(Self.rowHeight, (bounds.height - top) / CGFloat(max(weeks, 1))))
    }

    private func weekday(_ initial: String) -> NSAttributedString {
        NSAttributedString(
            string: initial,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.weekdaySize, weight: .semibold),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ])
    }

    override func draw(_: NSRect) {
        guard let grid, !grid.initials.isEmpty else { return }
        let metrics = metrics(of: grid)
        drawTitle(of: grid)
        let weekdayTop = Self.titleHeight + Self.gap
        for (index, initial) in grid.initials.enumerated() {
            centre(
                weekday(initial),
                in: NSRect(
                    x: CGFloat(index) * metrics.column, y: weekdayTop, width: metrics.column,
                    height: weekdayHeight))
        }
        for (index, day) in grid.days.enumerated() {
            let (week, place) = index.quotientAndRemainder(dividingBy: grid.initials.count)
            let cell = NSRect(
                x: CGFloat(place) * metrics.column, y: metrics.top + CGFloat(week) * metrics.row,
                width: metrics.column, height: metrics.row)
            drawDay(day, hovered: index == hovered, in: cell)
        }
    }

    private func drawTitle(of grid: AgendaMonth) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        NSAttributedString(
            string: "\(grid.name) \(grid.year)".localizedUppercase,
            attributes: [
                .font: Self.titleFont, .foregroundColor: NSColor.secondaryLabelColor,
                .kern: Self.titleKern, .paragraphStyle: style,
            ]
        )
        .draw(
            in: NSRect(
                x: 0, y: 0, width: max(bounds.width - reserved, 0), height: Self.titleHeight))
    }

    private func drawDay(_ day: AgendaMonth.Day, hovered: Bool, in cell: NSRect) {
        let size = min(Self.markSize, cell.height - Self.markInset - Self.markInset)
        let mark = NSRect(x: cell.midX - size * Self.half, y: cell.minY, width: size, height: size)
        if day.isToday {
            NSColor.labelColor.setFill()
            NSBezierPath(ovalIn: mark).fill()
        } else if hovered {
            NSColor.labelColor.withAlphaComponent(Self.hoverAlpha).setFill()
            NSBezierPath(ovalIn: mark).fill()
        }
        let colour: NSColor =
            if day.isToday {
                Self.todayText
            } else {
                day.isInMonth ? .labelColor : .tertiaryLabelColor
            }
        centre(
            NSAttributedString(
                string: day.number,
                attributes: [
                    .font: NSFont.systemFont(
                        ofSize: Self.daySize, weight: day.isToday ? .bold : .medium),
                    .foregroundColor: colour,
                ]),
            in: mark)
        drawDots(of: day, below: mark)
    }

    private func drawDots(of day: AgendaMonth.Day, below mark: NSRect) {
        let shown = day.events.prefix(Self.maxDots).map { colours[$0.id] ?? .controlAccentColor }
        let width = CGFloat(shown.count) * Self.dot + CGFloat(max(shown.count - 1, 0)) * Self.dotGap
        var left = mark.midX - width * Self.half
        for colour in shown {
            colour.withAlphaComponent(day.isInMonth ? 1 : Self.outsideDotAlpha).setFill()
            NSBezierPath(
                ovalIn: NSRect(
                    x: left, y: mark.maxY + Self.dotDrop, width: Self.dot, height: Self.dot)
            )
            .fill()
            left += Self.dot + Self.dotGap
        }
    }

    private func centre(_ text: NSAttributedString, in cell: NSRect) {
        let size = text.size()
        text.draw(
            at: NSPoint(
                x: cell.midX - size.width * Self.half, y: cell.midY - size.height * Self.half))
    }
}
