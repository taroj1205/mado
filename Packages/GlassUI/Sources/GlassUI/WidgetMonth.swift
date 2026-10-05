import AppCore
import AppKit

final class WidgetMonth: NSView {
    private static let titleSize: CGFloat = 11
    private static let titleKern: CGFloat = 0.4
    private static let weekdaySize: CGFloat = 9.5
    private static let daySize: CGFloat = 11
    private static let gap: CGFloat = 6
    private static let rowHeight: CGFloat = 20
    private static let markSize: CGFloat = 18
    private static let markInset: CGFloat = 1
    private static let half: CGFloat = 0.5
    private static let todayShade: CGFloat = 0.11
    private static let todayText = WidgetTile.tone(
        NSColor(white: todayShade, alpha: 1), .white, (dark: 1, light: 1))

    private(set) var month: CalendarMonth?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ month: CalendarMonth) {
        guard month != self.month else { return }
        self.month = month
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        guard let month, !month.weekdays.isEmpty else { return }
        let title = NSAttributedString(
            string: month.title.localizedUppercase,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.titleSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor, .kern: Self.titleKern,
            ])
        title.draw(at: .zero)
        let column = bounds.width / CGFloat(month.weekdays.count)
        let weekdayTop = title.size().height + Self.gap
        let weekday: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: Self.weekdaySize, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let names = month.weekdays.map { NSAttributedString(string: $0, attributes: weekday) }
        let height = names.map { $0.size().height }.max() ?? 0
        for (index, name) in names.enumerated() {
            centre(
                name,
                in: NSRect(x: CGFloat(index) * column, y: weekdayTop, width: column, height: height)
            )
        }
        let top = weekdayTop + height + Self.gap
        let weeks = (month.days.count + month.weekdays.count - 1) / month.weekdays.count
        let row = min(Self.rowHeight, (bounds.height - top) / CGFloat(max(weeks, 1)))
        for (index, day) in month.days.enumerated() {
            let (week, place) = index.quotientAndRemainder(dividingBy: month.weekdays.count)
            let cell = NSRect(
                x: CGFloat(place) * column, y: top + CGFloat(week) * row, width: column,
                height: row)
            if day.isToday {
                mark(in: cell)
            }
            centre(number(day), in: cell)
        }
    }

    private func number(_ day: CalendarMonth.Day) -> NSAttributedString {
        let colour: NSColor =
            if day.isToday {
                Self.todayText
            } else {
                day.isInMonth ? .labelColor : .tertiaryLabelColor
            }
        return NSAttributedString(
            string: day.number,
            attributes: [
                .font: NSFont.systemFont(
                    ofSize: Self.daySize, weight: day.isToday ? .bold : .medium),
                .foregroundColor: colour,
            ])
    }

    private func mark(in cell: NSRect) {
        let size = min(Self.markSize, cell.height - Self.markInset - Self.markInset)
        NSColor.labelColor.setFill()
        NSBezierPath(
            ovalIn: NSRect(
                x: cell.midX - size * Self.half, y: cell.midY - size * Self.half, width: size,
                height: size)
        )
        .fill()
    }

    private func centre(_ text: NSAttributedString, in cell: NSRect) {
        let size = text.size()
        text.draw(
            at: NSPoint(
                x: cell.midX - size.width * Self.half, y: cell.midY - size.height * Self.half))
    }
}
