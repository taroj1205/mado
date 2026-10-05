import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetPlacementTests {
    private static let frame = NSRect(x: 400, y: 200, width: 760, height: 548)
    private static let pitch = CGFloat(78 + WidgetGrid.gap)

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
        view.layoutSubtreeIfNeeded()
    }

    @Test func aPinnedTileKeepsItsCellAndTheOthersFlowAroundIt() {
        let cells = WidgetGrid.cells(
            spanning: [
                .init(size: .wide, pin: (column: 0, row: 0)), .init(size: .wide),
                .init(size: .small, pin: (column: 5, row: 1)), .init(size: .wide),
            ])
        #expect(cells.map(\.columns) == [0..<2, 2..<4, 5..<6, 4..<6])
        #expect(cells.map(\.row) == [0, 0, 1, 0])
    }

    @Test func aPinThatCollidesOrOverhangsFallsBackToTheFlow() {
        let cells = WidgetGrid.cells(
            spanning: [
                .init(size: .wide, pin: (column: 1, row: 0)),
                .init(size: .wide, pin: (column: 2, row: 0)),
                .init(size: .wide, pin: (column: 5, row: 0)),
            ])
        #expect(cells.map(\.columns) == [1..<3, 3..<5, 0..<2])
        #expect(cells.map(\.row) == [0, 0, 1])
    }

    @Test func aPinnedSpotRoundTripsThroughItsName() throws {
        let spot = WidgetGrid.Spot.cell(column: 3, row: 1)
        #expect(spot.name == "in_panel:3:1")
        #expect(WidgetGrid.Spot(name: spot.name) == spot)
        #expect(spot.isPinned)
        #expect(!WidgetGrid.Spot.panel.isPinned)
        #expect(WidgetGrid.Spot(name: "in_panel") == .panel)
        let saved = try JSONEncoder().encode(["a": spot])
        #expect(
            try JSONDecoder().decode([String: WidgetGrid.Spot].self, from: saved) == ["a": spot])
        #expect(spot.title == "In the panel")
        #expect(spot.preset == .panel)
    }

    @Test func aPinnedTileSitsOnItsRowAndColumnWhileTheRestKeepReadingOrder() {
        view.widgetSpots = ["1": .cell(column: 3, row: 1)]
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.shown.map(\.id) == ["1", "2", "3", "4", "5", "6", "7"])
        let frames = view.widgetGrid.tiles.map(\.frame)
        let column = (732 - 5 * 8) / 6.0
        #expect(abs(frames[0].minX - 14 - 3 * (column + 8)) < 0.01)
        #expect(frames[0].minY == 12 + Self.pitch)
        #expect(frames[1...6].map(\.minY) == Array(repeating: 12, count: 6))
        #expect(view.widgetGrid.inPanel.count == 7)
    }

    @Test func draggingOntoAnEmptyCellPinsTheWidgetThere() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetGrid.tiles[0].onDragStart?()
        let frames = view.widgetGrid.tileFrames(in: panel)
        let step = frames[6].width + WidgetGrid.gap
        let empty = CGPoint(x: frames[6].midX + 3 * step, y: frames[6].midY)
        #expect(view.dragWidget("1", at: empty, from: nil) == .move)
        let board = view.widgetGrid.rails.board
        #expect(board.model.ghost?.spot == .cell(column: 3, row: 1))
        #expect(view.dropWidget("1"))
        #expect(edits == [.place("1", .cell(column: 3, row: 1), before: nil)])
    }

    @Test func draggingOverAnotherTileStillReordersTheFlow() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgetGrid.tiles[0].onDragStart?()
        let frames = view.widgetGrid.tileFrames(in: panel)
        let over = CGPoint(x: frames[2].midX, y: frames[2].midY)
        #expect(view.dragWidget("1", at: over, from: nil) == .move)
        #expect(view.widgetGrid.shown.map(\.id) == ["2", "3", "1", "4", "5", "6", "7"])
        #expect(view.widgetGrid.rails.board.model.ghost == nil)
    }

    @Test func aPinThatWouldCoverAnotherPinnedTileIsRefused() {
        view.widgetSpots = ["1": .cell(column: 0, row: 1), "2": .cell(column: 4, row: 1)]
        let grid = view.widgetGrid
        #expect(grid.accepts("3", at: .cell(column: 2, row: 1), before: nil))
        #expect(!grid.accepts("3", at: .cell(column: 0, row: 1), before: nil))
        #expect(!grid.accepts("3", at: .cell(column: 4, row: 1), before: nil))
    }

    @Test func aTallPinnedTileMustStayInsideTwoRows() {
        view.widgetSizes = ["1": .init(columns: 2, rows: 2)]
        #expect(!view.widgetGrid.accepts("1", at: .cell(column: 0, row: 1), before: nil))
        #expect(view.widgetGrid.accepts("1", at: .cell(column: 0, row: 0), before: nil))
    }

    @Test func belowTilesMirrorTheShelfAboveAndStartSixteenPointsUnderThePanel() {
        let area = Self.frame
        let group = [numbered(1), numbered(2)]
        let frames = WidgetGrid.frames(of: group, at: .belowLeft, beside: area)
        #expect(frames.map(\.maxY) == [area.minY - WidgetGrid.lift, area.minY - WidgetGrid.lift])
        #expect(frames[0].minX == area.minX)
        #expect(frames[1].minX == frames[0].maxX + WidgetGrid.gap)
        let lower = WidgetGrid.frames(
            of: group, at: .below(column: 0, row: 1), beside: area)
        #expect(lower[0].maxY == frames[0].minY - WidgetGrid.gap)
        #expect(
            WidgetGrid.shelfRows(of: group.map { ($0, .below(column: 0, row: 1)) }, on: .below) == 2
        )
        #expect(WidgetGrid.shelfRows(of: group.map { ($0, .belowLeft) }, on: .above) == 0)
    }

    @Test func aTileBelowTheLauncherPullsItUpByHalfItsReach() {
        view.widgetSpots = ["1": .belowCentre]
        #expect(view.widgetShift == -94)
        view.widgetSpots = ["1": .belowCentre, "2": .aboveCentre]
        #expect(view.widgetShift == 0)
    }

    @Test func railTilesSnapToTheInlineRowsAndGap() {
        let area = Self.frame
        let group = [numbered(1), numbered(2), numbered(3)]
        let frames = WidgetGrid.frames(of: group, at: .leftTop, beside: area)
        #expect(frames.map(\.height) == [78, 78, 78])
        #expect(frames[0].minY - frames[1].maxY == WidgetGrid.gap)
        #expect(frames[1].minY - frames[2].maxY == WidgetGrid.gap)
        let down = WidgetGrid.frames(of: group, at: .beside(.left, row: 2), beside: area)
        #expect(down[0].maxY == area.maxY - 2 * Self.pitch)
    }

    @Test func railTilesResizeToSquares() {
        var square = numbered(1)
        square.resized = .init(columns: 2, rows: 2)
        var big = numbered(2)
        big.resized = .init(columns: 3, rows: 3)
        let frames = WidgetGrid.frames(of: [square], at: .rightTop, beside: Self.frame)
        #expect(frames[0].width == frames[0].height)
        #expect(frames[0].width == 164)
        let large = WidgetGrid.frames(of: [big], at: .rightTop, beside: Self.frame)
        #expect(large[0].width == large[0].height)
        #expect(large[0].width == 250)
        #expect(numbered(3).railSize == .init(columns: 3))
    }

    @Test func railUnitsPushEachOtherDownInsteadOfOverlapping() {
        #expect(WidgetGrid.resolved([(0, 2), (1, 2), (1, 1)], within: 6) == [0, 2, 4])
        #expect(WidgetGrid.resolved([(4, 2), (5, 1)], within: 6) == [3, 5])
        #expect(WidgetGrid.resolved([(5, 2)], within: 6) == [4])
    }

    @Test func aRailAcceptsTilesOnlyWhileTheirRowsFitBesideThePanel() {
        let rows = WidgetGrid.railRows(of: Self.frame)
        #expect(rows == 6)
        view.widgetSpots = Dictionary(
            uniqueKeysWithValues: (1...5).map { ("\($0)", .beside(.left, row: $0 - 1)) })
        #expect(view.widgetGrid.accepts("6", at: .beside(.left, row: 5), before: nil))
        view.widgetSpots = Dictionary(
            uniqueKeysWithValues: (1...6).map { ("\($0)", .beside(.left, row: $0 - 1)) })
        #expect(!view.widgetGrid.accepts("7", at: .beside(.left, row: 0), before: nil))
    }

    @Test func aBelowTileMayUseAnyRowOfTheShelfAndATwoRowTileMayStartOnTheSecond() {
        view.widgetSizes = ["2": .init(columns: 1, rows: 2)]
        let grid = view.widgetGrid
        #expect(grid.accepts("1", at: .below(column: 0, row: 2), before: nil))
        #expect(grid.accepts("1", at: .below(column: 0, row: 1), before: nil))
        #expect(grid.accepts("2", at: .below(column: 0, row: 1), before: nil))
    }

    @Test func theStripKeepsOnlyTheTilesThatStayOnItsRowOnceThePinsAreApplied() {
        view.widgetSizes = ["1": .wide, "2": .wide, "3": .wide]
        view.widgetSpots = ["1": .cell(column: 1, row: 0)]
        view.widgetLayout = .strip
        #expect(view.widgetGrid.inPanel.map(\.id) == ["1", "2"])
        #expect(view.widgetGrid.panelCells.allSatisfy { $0.row == 0 })
    }

    @Test func aTileIsValidatedAgainstTheLimitsOfTheSideItMovesTo() {
        view.widgetSpots = ["1": .leftTop]
        view.widgetSizes = ["1": .init(columns: 2, rows: 3)]
        #expect(view.widgetGrid.accepts("1", at: .cell(column: 0, row: 0), before: nil))
        #expect(view.widgetGrid.accepts("1", at: .belowLeft, before: nil))
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
    }
}
