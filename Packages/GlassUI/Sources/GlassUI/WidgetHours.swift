import AppKit

final class WidgetHours: NSView {
    private static let cellWidth: CGFloat = 36
    private static let rowsBelow: CGFloat = 100
    private static let rowHeight: CGFloat = 20
    private static let maxRows = 3
    private static let columnHeight: CGFloat = 48
    private static let symbolSize: CGFloat = 14
    private static let labelGap: CGFloat = 3
    private static let rowGap: CGFloat = 6
    private static let half: CGFloat = 0.5

    private(set) var hours: [WidgetGrid.Hour] = []

    override var isFlipped: Bool { true }

    var isStacked: Bool { bounds.width < Self.rowsBelow }

    static func quantum(forWidth width: CGFloat) -> CGFloat? {
        width < rowsBelow ? rowHeight : nil
    }

    static func height(of hours: Int, forWidth width: CGFloat) -> CGFloat {
        width < rowsBelow ? CGFloat(min(hours, maxRows)) * rowHeight : columnHeight
    }

    func show(_ hours: [WidgetGrid.Hour]) {
        guard hours != self.hours else { return }
        self.hours = hours
        needsDisplay = true
    }

    func visibleCount() -> Int {
        if isStacked {
            return min(hours.count, Int(bounds.height / Self.rowHeight))
        }
        return min(hours.count, Int(bounds.width / Self.cellWidth))
    }

    override func draw(_: NSRect) {
        let count = visibleCount()
        for (index, hour) in hours.prefix(count).enumerated() {
            if isStacked {
                drawRow(hour, at: CGFloat(index), now: index == 0)
            } else {
                drawColumn(hour, at: index, of: count, now: index == 0)
            }
        }
    }

    private func drawColumn(_ hour: WidgetGrid.Hour, at index: Int, of count: Int, now: Bool) {
        let width = bounds.width / CGFloat(count)
        let label = WidgetInk.hourLabel.height
        let value = WidgetInk.hourValue.height
        let stack = label + Self.symbolSize + value + Self.labelGap + Self.labelGap
        let top = bounds.midY - stack * Self.half
        let column = NSRect(x: CGFloat(index) * width, y: 0, width: width, height: bounds.height)
        WidgetInk.draw(
            hour.label, now ? WidgetInk.hourNow : WidgetInk.hourLabel,
            in: NSRect(x: column.minX, y: top, width: width, height: label), align: .center)
        let symbol = NSRect(
            x: column.minX, y: top + label + Self.labelGap, width: width, height: Self.symbolSize)
        WidgetInk.drawSymbol(
            hour.symbol, size: Self.symbolSize, colour: WidgetInk.tint, centredIn: symbol)
        WidgetInk.draw(
            hour.value, WidgetInk.hourValue,
            in: NSRect(
                x: column.minX, y: symbol.maxY + Self.labelGap, width: width, height: value),
            align: .center)
    }

    private func drawRow(_ hour: WidgetGrid.Hour, at index: CGFloat, now: Bool) {
        let row = NSRect(
            x: 0, y: index * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
        let label = WidgetInk.hourLabel.width(of: "00 AM")
        let value = WidgetInk.hourValue.width(of: "-00°")
        WidgetInk.draw(
            hour.label, now ? WidgetInk.hourNow : WidgetInk.hourLabel,
            in: NSRect(x: row.minX, y: row.minY, width: label, height: row.height))
        WidgetInk.drawSymbol(
            hour.symbol, size: Self.symbolSize, colour: WidgetInk.tint,
            centredIn: NSRect(
                x: row.midX - Self.rowGap, y: row.minY, width: Self.symbolSize,
                height: row.height))
        WidgetInk.draw(
            hour.value, WidgetInk.hourValue,
            in: NSRect(x: row.maxX - value, y: row.minY, width: value, height: row.height),
            align: .right)
    }
}
