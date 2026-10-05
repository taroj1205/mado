import AppKit
import Testing

@testable import GlassUI

private let widths = (narrow: 115.0, medium: 238.0, wide: 361.0)
private let heights = (short: 78.0, tall: 164.0, tallest: 250.0)
private let tileSizes: [NSSize] = [
    NSSize(width: widths.narrow, height: heights.short),
    NSSize(width: widths.medium, height: heights.short),
    NSSize(width: widths.wide, height: heights.short),
    NSSize(width: widths.narrow, height: heights.tall),
    NSSize(width: widths.medium, height: heights.tall),
    NSSize(width: widths.wide, height: heights.tall),
    NSSize(width: widths.wide, height: heights.tallest),
]

@MainActor
@Suite struct WidgetFaceTests {
    private static let hours = (0..<8).map { index in
        WidgetGrid.Hour(
            label: index == 0 ? "Now" : "\(index) PM", symbol: "cloud.sun", value: "\(index)°")
    }

    private static let facts = [
        WidgetGrid.Fact(name: "Feels like", value: "10°"),
        .init(name: "Humidity", value: "77%"), .init(name: "Wind", value: "14 km/h"),
        .init(name: "Rain", value: "35%"),
    ]

    private static let weather = WidgetGrid.Widget(
        id: "weather", name: "Weather", value: "12°", detail: "Partly cloudy", action: "",
        spoken: "", symbol: "cloud.sun",
        span: .init(low: "9°", high: "15°", position: 0.5, cold: .systemTeal, warm: .systemGreen),
        hours: hours, facts: facts)

    private static let clock = WidgetGrid.Widget(
        id: "clock", name: "Clock", value: "21:55", detail: "Mon, Oct 5", action: "", spoken: "",
        facts: Array(facts.prefix(3)))

    private static let system = WidgetGrid.Widget(
        id: "system", name: "System",
        meters: [
            .init(name: "CPU", value: "30%", level: 0.3),
            .init(name: "RAM", value: "77%", level: 0.77),
        ], action: "", spoken: "", facts: facts)

    private func tile(_ widget: WidgetGrid.Widget, _ size: NSSize) -> WidgetTile {
        let tile = WidgetTile(floating: false)
        tile.frame = NSRect(origin: .zero, size: size)
        tile.show(widget)
        tile.layoutSubtreeIfNeeded()
        return tile
    }

    private func shown(_ face: WidgetFace) -> [NSView] {
        (face.subviews.filter { !$0.isHidden })
    }

    @Test func aTilesFormComesFromItsSize() {
        #expect(WidgetForm(size: NSSize(width: 115, height: 78)).isPlain)
        #expect(WidgetForm(size: NSSize(width: 238, height: 78)).reach == .medium)
        #expect(WidgetForm(size: NSSize(width: 361, height: 78)).reach == .wide)
        #expect(WidgetForm(size: NSSize(width: 115, height: 164)).tall)
        #expect(!WidgetForm(size: NSSize(width: 115, height: 164)).isPlain)
        #expect(!WidgetForm(size: NSSize(width: 361, height: 78)).tall)
    }

    @Test func theSmallestSizeKeepsTheOriginalTile() {
        let small = tile(Self.weather, tileSizes[0])
        #expect(small.face.isHidden)
        #expect(!small.lines.isHidden)
        #expect(small.value.stringValue == "12°")
    }

    @Test func growingATileSwapsItsLinesForTheFaceAndShrinkingSwapsThemBack() {
        let grown = tile(Self.weather, tileSizes[1])
        #expect(!grown.face.isHidden)
        #expect(grown.lines.isHidden)
        grown.frame = NSRect(origin: .zero, size: tileSizes[0])
        grown.layoutSubtreeIfNeeded()
        #expect(grown.face.isHidden)
        #expect(!grown.lines.isHidden)
    }

    @Test func aWiderTileShowsMoreHours() {
        let counts = [1, 2].map { index in
            tile(Self.weather, tileSizes[index]).face.hours.visibleCount()
        }
        #expect(counts == [3, 6])
        #expect(tile(Self.weather, tileSizes[5]).face.hours.visibleCount() == 8)
    }

    @Test func aTallTileStacksTheHeaderTheRangeTheHoursAndTheFacts() {
        let face = tile(Self.clock, tileSizes[4]).face
        let tops = [face.value, face.detail, face.facts].map(\.frame.minY)
        #expect(tops == tops.sorted())
        #expect(!face.facts.isHidden)
        #expect(face.hours.isHidden)
        let forecast = tile(Self.weather, tileSizes[4]).face
        #expect(!forecast.span.isHidden)
        #expect(forecast.span.frame.maxY <= forecast.hours.frame.minY)
        #expect(forecast.facts.isHidden)
    }

    @Test func aWideTallTileMovesTheFactsBesideTheHeader() {
        let face = tile(Self.weather, tileSizes[5]).face
        #expect(!face.facts.isHidden)
        #expect(face.facts.frame.minX >= face.value.frame.maxX)
        #expect(face.facts.frame.maxY <= face.span.frame.minY)
    }

    @Test func theStripLeavesOutTheRange() {
        let compact = WidgetTile(floating: false)
        compact.compact = true
        compact.frame = NSRect(x: 0, y: 0, width: 238, height: 72)
        compact.show(Self.weather)
        compact.layoutSubtreeIfNeeded()
        #expect(compact.face.span.isHidden)
        #expect(!compact.face.hours.isHidden)
    }

    @Test func metersBecomeRingsOnAWideTallTileAndBarsOnANarrowOne() {
        let wide = tile(Self.system, tileSizes[4]).face
        #expect(wide.gauges.map(\.style) == [.ring, .ring])
        let narrow = tile(Self.system, tileSizes[3]).face
        #expect(narrow.gauges.map(\.style) == [.bar, .bar])
        #expect(tile(Self.system, tileSizes[1]).face.gauges.map(\.style) == [.bar, .bar])
    }

    @Test func factsBalanceAcrossColumnsAndStopWhenTheRowsRunOut() {
        let list = WidgetFacts()
        list.show(Self.facts)
        list.frame = NSRect(x: 0, y: 0, width: 214, height: 38)
        #expect(list.visibleCount() == 4)
        list.frame = NSRect(x: 0, y: 0, width: 91, height: 38)
        #expect(list.visibleCount() == 2)
        list.frame = NSRect(x: 0, y: 0, width: 214, height: 10)
        #expect(list.visibleCount() == 2)
    }

    @Test(arguments: tileSizes)
    func nothingDrawnLeavesTheTileOrOverlapsAnother(size: NSSize) {
        for widget in [Self.weather, Self.clock, Self.system] {
            let face = tile(widget, size).face
            let inner = face.bounds.insetBy(dx: WidgetTile.horizontal, dy: WidgetTile.vertical)
            let visible = shown(face).filter { $0 !== face.divider }
            if face.isHidden { continue }
            for view in visible {
                #expect(
                    inner.insetBy(dx: -1, dy: -1).contains(view.frame),
                    "\(widget.id) \(size): \(view) leaves the tile")
            }
            for (index, one) in visible.enumerated() {
                for other in visible[(index + 1)...] {
                    #expect(
                        !one.frame.insetBy(dx: 0.5, dy: 0.5).intersects(other.frame),
                        "\(widget.id) \(size): \(one) overlaps \(other)")
                }
            }
        }
    }
}
