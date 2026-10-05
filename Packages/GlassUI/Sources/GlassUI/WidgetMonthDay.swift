import AppCore
import AppKit

final class WidgetMonthDay: NSView {
    private static let titleSize: CGFloat = 11
    private static let labelSize: CGFloat = 9.5
    private static let numberSize: CGFloat = 34
    private static let eventSize: CGFloat = 11.5
    private static let detailSize: CGFloat = 10
    private static let titleFont = NSFont.systemFont(ofSize: titleSize, weight: .semibold)
    private static let labelFont = NSFont.systemFont(ofSize: labelSize, weight: .semibold)
    private static let numberFont = NSFont.monospacedDigitSystemFont(
        ofSize: numberSize, weight: .semibold)
    private static let countFont = NSFont.systemFont(ofSize: detailSize)
    private static let eventFont = NSFont.systemFont(ofSize: eventSize, weight: .medium)
    private static let moreFont = NSFont.systemFont(ofSize: detailSize, weight: .medium)
    private static let emptyFont = NSFont.systemFont(ofSize: titleSize)
    private static let titleKern: CGFloat = 0.4
    private static let numberKern: CGFloat = -0.6
    private static let chevron = (width: 5.0, height: 9.0, line: 1.6)
    private static let chevronGap: CGFloat = 6
    private static let reach: CGFloat = 3
    private static let contentGap: CGFloat = 10
    private static let rail: CGFloat = 54
    private static let railGap: CGFloat = 12
    private static let labelGap: CGFloat = 2
    private static let rowHeight: CGFloat = 28
    private static let rowGap: CGFloat = 4
    private static let moreHeight: CGFloat = 14
    private static let bar: CGFloat = 3
    private static let barGap: CGFloat = 8
    private static let half: CGFloat = 0.5
    private static let titleHeight = NSAttributedString(
        string: "A", attributes: [.font: titleFont]
    )
    .size().height

    private(set) var day: AgendaMonth.Day?
    private var colours: [String: NSColor] = [:]
    private var title = NSAttributedString()
    var reserved: CGFloat = 0 {
        didSet {
            if reserved != oldValue { needsDisplay = true }
        }
    }
    var isBackHovered = false {
        didSet {
            if isBackHovered != oldValue { needsDisplay = true }
        }
    }

    override var isFlipped: Bool { true }

    var backRect: NSRect {
        let width = Self.chevron.width + Self.chevronGap + title.size().width
        return NSRect(
            x: 0, y: 0, width: min(width, max(bounds.width - reserved, 0)),
            height: Self.titleHeight
        )
        .insetBy(dx: -Self.reach, dy: -Self.reach)
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

    private static func text(
        _ string: String, font: NSFont, colour: NSColor, kern: CGFloat = 0
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: string,
            attributes: [
                .font: font, .foregroundColor: colour, .kern: kern, .paragraphStyle: style,
            ])
    }

    private static func count(of events: [Agenda.Event]) -> String {
        events.count == 1 ? "1 event" : "\(events.count) events"
    }

    private static func time(of event: Agenda.Event) -> String {
        let hours =
            event.isAllDay
            ? "All day" : (event.start..<event.end).formatted(.interval.hour().minute())
        return [hours, event.place].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func show(_ next: AgendaMonth.Day, colours: [String: NSColor]) {
        guard next != day || colours != self.colours else { return }
        if next.start != day?.start {
            let sameYear = Calendar.current.isDate(next.start, equalTo: .now, toGranularity: .year)
            title = Self.text(
                next.start.formatted(
                    sameYear ? .dateTime.month(.wide) : .dateTime.month(.abbreviated).year()
                )
                .localizedUppercase,
                font: Self.titleFont, colour: .secondaryLabelColor, kern: Self.titleKern)
        }
        day = next
        self.colours = colours
        needsDisplay = true
    }

    override func draw(_: NSRect) {
        guard let day else { return }
        drawBack()
        let top = Self.titleHeight + Self.contentGap
        drawRail(of: day, top: top)
        let left = Self.rail + Self.railGap
        drawEvents(
            of: day,
            in: NSRect(
                x: left, y: top, width: max(bounds.width - left, 0), height: bounds.height - top))
    }

    private func drawBack() {
        let colour: NSColor = isBackHovered ? .labelColor : .secondaryLabelColor
        let line = Self.chevron.line
        let middle = Self.titleHeight * Self.half
        let path = NSBezierPath()
        path.move(
            to: NSPoint(x: line + Self.chevron.width, y: middle - Self.chevron.height * Self.half))
        path.line(to: NSPoint(x: line, y: middle))
        path.line(
            to: NSPoint(x: line + Self.chevron.width, y: middle + Self.chevron.height * Self.half))
        path.lineWidth = line
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        colour.setStroke()
        path.stroke()
        let left = line + Self.chevron.width + Self.chevronGap
        let width = max(bounds.width - reserved - left, 0)
        let shown = NSMutableAttributedString(attributedString: title)
        shown.addAttribute(
            .foregroundColor, value: colour, range: NSRange(location: 0, length: shown.length))
        shown.draw(in: NSRect(x: left, y: 0, width: width, height: Self.titleHeight))
    }

    private func drawRail(of day: AgendaMonth.Day, top: CGFloat) {
        var cursor = top
        let label = Self.text(
            day.isToday
                ? "TODAY" : day.start.formatted(.dateTime.weekday(.abbreviated)).localizedUppercase,
            font: Self.labelFont, colour: day.isToday ? .controlAccentColor : .tertiaryLabelColor,
            kern: Self.titleKern)
        cursor = place(label, at: cursor, width: Self.rail)
        cursor = place(
            Self.text(
                day.number, font: Self.numberFont, colour: .labelColor, kern: Self.numberKern),
            at: cursor + Self.labelGap, width: Self.rail)
        if !day.events.isEmpty {
            _ = place(
                Self.text(
                    Self.count(of: day.events), font: Self.countFont, colour: .secondaryLabelColor),
                at: cursor + Self.labelGap, width: Self.rail + Self.railGap)
        }
        NSColor.separatorColor.setFill()
        NSRect(
            x: Self.rail + Self.railGap * Self.half, y: top, width: 1, height: bounds.height - top
        ).fill()
    }

    @discardableResult
    private func place(_ text: NSAttributedString, at top: CGFloat, width: CGFloat) -> CGFloat {
        let height = text.size().height
        text.draw(in: NSRect(x: 0, y: top, width: width, height: height))
        return top + height
    }

    private func drawEvents(of day: AgendaMonth.Day, in area: NSRect) {
        guard !day.events.isEmpty else {
            let empty = Self.text(
                "Nothing planned", font: Self.emptyFont, colour: .tertiaryLabelColor)
            let size = empty.size()
            empty.draw(
                at: NSPoint(x: area.minX, y: area.midY - size.height * Self.half - Self.contentGap))
            return
        }
        let pitch = Self.rowHeight + Self.rowGap
        let fits = Int((area.height + Self.rowGap) / pitch)
        let rows =
            day.events.count <= fits
            ? day.events.count : max(Int((area.height - Self.moreHeight) / pitch), 1)
        for (index, event) in day.events.prefix(rows).enumerated() {
            drawRow(
                of: event,
                in: NSRect(
                    x: area.minX, y: area.minY + CGFloat(index) * pitch, width: area.width,
                    height: Self.rowHeight))
        }
        guard day.events.count > rows else { return }
        let more = Self.text(
            "+\(day.events.count - rows) more", font: Self.moreFont, colour: .tertiaryLabelColor)
        more.draw(
            in: NSRect(
                x: area.minX + Self.bar + Self.barGap, y: area.minY + CGFloat(rows) * pitch,
                width: area.width, height: Self.moreHeight))
    }

    private func drawRow(of event: Agenda.Event, in row: NSRect) {
        (colours[event.id] ?? .controlAccentColor).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: row.minX, y: row.minY, width: Self.bar, height: row.height),
            xRadius: Self.bar * Self.half, yRadius: Self.bar * Self.half
        )
        .fill()
        let left = row.minX + Self.bar + Self.barGap
        let width = max(row.maxX - left, 0)
        let heading = Self.text(event.title, font: Self.eventFont, colour: .labelColor)
        let detail = Self.text(
            Self.time(of: event), font: Self.countFont, colour: .secondaryLabelColor)
        let used = heading.size().height + detail.size().height
        var offset = row.minY + (row.height - used) * Self.half
        for line in [heading, detail] {
            let height = line.size().height
            line.draw(in: NSRect(x: left, y: offset, width: width, height: height))
            offset += height
        }
    }
}
