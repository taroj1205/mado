import AppKit

final class WidgetFacts: NSView {
    static let rowHeight: CGFloat = 19
    private static let columnWidth: CGFloat = 100
    private static let widest: CGFloat = 150
    private static let columnGap: CGFloat = 12
    private static let nameGap: CGFloat = 6
    private static let nameShare: CGFloat = 0.55
    private static let maxRows = 3

    private(set) var facts: [WidgetGrid.Fact] = []

    override var isFlipped: Bool { true }

    private var rowsFit: Int {
        max(Int(bounds.height / Self.rowHeight), 1)
    }

    static func columns(forWidth width: CGFloat) -> Int {
        max(1, Int((width + columnGap) / (columnWidth + columnGap)))
    }

    static func height(of facts: Int, forWidth width: CGFloat) -> CGFloat {
        let wide = columns(forWidth: width)
        return CGFloat(min((facts + wide - 1) / wide, maxRows)) * rowHeight
    }

    func show(_ facts: [WidgetGrid.Fact]) {
        guard facts != self.facts else { return }
        self.facts = facts
        needsDisplay = true
    }

    func visibleCount() -> Int {
        min(facts.count, Self.columns(forWidth: bounds.width) * rowsFit)
    }

    override func draw(_: NSRect) {
        let count = visibleCount()
        guard count > 0 else { return }
        let columns = min(Self.columns(forWidth: bounds.width), (count + rowsFit - 1) / rowsFit)
        let rows = (count + columns - 1) / columns
        let width = min(
            (bounds.width - CGFloat(columns - 1) * Self.columnGap) / CGFloat(columns),
            Self.widest)
        for (index, fact) in facts.prefix(count).enumerated() {
            let cell = NSRect(
                x: CGFloat(index / rows) * (width + Self.columnGap),
                y: CGFloat(index % rows) * Self.rowHeight, width: width, height: Self.rowHeight)
            draw(fact, in: cell)
        }
    }

    private func draw(_ fact: WidgetGrid.Fact, in cell: NSRect) {
        let name = min(WidgetInk.caption.width(of: fact.name), cell.width * Self.nameShare)
        let room = max(cell.width - name - Self.nameGap, 0)
        let value = min(WidgetInk.factValue.width(of: fact.value), room)
        WidgetInk.draw(
            fact.name, WidgetInk.caption,
            in: NSRect(x: cell.minX, y: cell.minY, width: name, height: cell.height))
        WidgetInk.draw(
            fact.value, WidgetInk.factValue,
            in: NSRect(x: cell.maxX - value, y: cell.minY, width: value, height: cell.height),
            align: .right)
    }
}
