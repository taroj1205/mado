import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSizeTests {
    private static let panel = CGRect(x: 400, y: 200, width: 760, height: 548)

    private func widget(_ id: String, _ size: WidgetGrid.Size) -> WidgetGrid.Widget {
        var made = WidgetGrid.Widget(
            id: id, name: id, value: id, detail: "", action: "", spoken: id)
        made.resized = size
        return made
    }

    @Test func theNamedSizesCarryTheirDimensionsAndEverythingElseJustTheNumbers() {
        #expect(WidgetGrid.Size.small.title == "Small · 1 × 1")
        #expect(WidgetGrid.Size.wide.title == "Medium · 2 × 1")
        #expect(WidgetGrid.Size.large.title == "Large · 2 × 2")
        #expect(WidgetGrid.Size.extraLarge.title == "Extra Large · 4 × 2")
        #expect(WidgetGrid.Size(columns: 3, rows: 2).title == "3 × 2")
        #expect(WidgetGrid.Size(columns: 2, rows: 3).rowsTitle == "3 rows")
        #expect(WidgetGrid.Size.small.rowsTitle == "1 row")
    }

    @Test func tilesKeepToTheirOwnRangeAndThePanelHoldsThreeRows() {
        let grid = WidgetGrid()
        let plain = widget("a", .small)
        #expect(grid.range(of: plain, on: .panel) == (.small, .init(columns: 3, rows: 2)))
        #expect(grid.range(of: plain, on: .left) == (.wide, .init(columns: 3, rows: 2)))
        #expect(WidgetGrid.maxPanelRows == 3)
        #expect(WidgetGrid.tallest(on: .above) == 2)
    }

    @Test func aTallTileHoldsItsColumnsForTwoRowsAndLaterTilesFlowAround() {
        let cells = WidgetGrid.cells(
            spanning: [
                .init(columns: 2, rows: 2), .init(columns: 3), .small, .wide, .small,
            ])
        #expect(cells.map(\.columns) == [0..<2, 2..<5, 5..<6, 2..<4, 4..<5])
        #expect(cells.map(\.rows) == [0..<2, 0..<1, 0..<1, 1..<2, 1..<2])
        #expect(
            WidgetGrid.rowCount(
                of: WidgetGrid.cells(spanning: [.init(columns: 2, rows: 2), .small]))
                == 2)
        #expect(WidgetGrid.rowCount(of: []) == 0)
    }

    @Test func tilesOfOneRowKeepTheirOldReadingOrder() {
        let cells = WidgetGrid.cells(spanning: [.wide, .wide, .small, .small, .small])
        #expect(cells.map(\.row) == [0, 0, 0, 0, 1])
        #expect(cells.map(\.columns) == [0..<2, 2..<4, 4..<5, 5..<6, 0..<1])
    }

    @Test func theStripTreatsEveryTileAsOneRow() {
        let tall = widget("tall", .init(columns: 2, rows: 2))
        #expect(tall.size(in: .strip) == .wide)
        #expect(tall.size(in: .grid) == .init(columns: 2, rows: 2))
        #expect(WidgetGrid.cells(of: [tall, tall], in: .strip).map(\.row) == [0, 0])
    }

    @Test func aTallShelfTileSitsOnItsFloorAndTheOnesBesideItStayShort() {
        let group = [widget("a", .init(columns: 2, rows: 2)), widget("b", .small)]
        let frames = WidgetGrid.frames(of: group, at: .aboveLeft, beside: Self.panel)
        let tall = frames[0]
        let short = frames[1]
        #expect(tall.minY == Self.panel.maxY + WidgetGrid.lift)
        #expect(tall.height == 2 * 78 + WidgetGrid.gap)
        #expect(short.height == 78)
        #expect(short.maxY == tall.maxY)
        #expect(WidgetGrid.shelfRows(of: group.map { ($0, .aboveLeft) }, on: .above) == 2)
    }

    @Test func railTilesStackByTheirOwnHeights() {
        let group = [widget("a", .init(columns: 2, rows: 2)), widget("b", .small)]
        let frames = WidgetGrid.frames(of: group, at: .leftTop, beside: Self.panel)
        #expect(frames.map(\.height) == [2 * 78 + WidgetGrid.gap, 78])
        #expect(frames[0].maxY == Self.panel.maxY)
        #expect(frames[1].maxY == frames[0].minY - WidgetGrid.gap)
        #expect(frames.map(\.width) == [2 * 78 + WidgetGrid.gap, 2 * 78 + WidgetGrid.gap])
        let bottom = WidgetGrid.frames(of: group, at: .leftBottom, beside: Self.panel)
        let last = CGFloat(WidgetGrid.railRows(of: Self.panel) - 3)
        #expect(bottom[0].maxY == Self.panel.maxY - last * (78 + WidgetGrid.gap))
    }

    @Test func sizesReadTheOldColumnsAndTheNewColumnsByRows() throws {
        let decoder = JSONDecoder()
        let old = try decoder.decode([String: WidgetGrid.Size].self, from: Data(#"{"a":3}"#.utf8))
        #expect(old == ["a": .init(columns: 3)])
        let new = try decoder.decode(
            [String: WidgetGrid.Size].self, from: Data(#"{"a":"2x2"}"#.utf8))
        #expect(new == ["a": .init(columns: 2, rows: 2)])
        #expect(throws: DecodingError.self) {
            try decoder.decode([String: WidgetGrid.Size].self, from: Data(#"{"a":"wide"}"#.utf8))
        }
        let saved = try JSONEncoder().encode(["a": WidgetGrid.Size(columns: 3, rows: 2)])
        #expect(String(bytes: saved, encoding: .utf8) == #"{"a":"3x2"}"#)
    }

    @Test func savedSettingsFromBeforeRowsStillLoadTheirWidths() throws {
        let json = #"{"custom":true,"added":["clock","system"],"sizes":{"clock":3}}"#
        let settings = try JSONDecoder().decode(WidgetSettings.self, from: Data(json.utf8))
        #expect(
            settings.sizes(from: ["clock", "system"]) == ["clock": .init(columns: 3)])
        var edited = settings
        edited.apply(.resize("system", .init(columns: 2, rows: 2)), from: ["clock", "system"])
        let again = try JSONDecoder().decode(
            WidgetSettings.self, from: JSONEncoder().encode(edited))
        #expect(again == edited)
    }

    @Test func sizesAreNamedLikeTheCanvasAndOtherOnesReadAsColumnsByRows() {
        #expect(WidgetGrid.Size.small.title == "Small · 1 × 1")
        #expect(WidgetGrid.Size.wide.title == "Medium · 2 × 1")
        #expect(WidgetGrid.Size(columns: 2, rows: 2).title == "Large · 2 × 2")
        #expect(WidgetGrid.Size(columns: 3, rows: 2).title == "3 × 2")
    }
}
