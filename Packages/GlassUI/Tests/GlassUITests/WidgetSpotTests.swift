import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetSpotTests {
    private static let frame = NSRect(x: 100, y: 100, width: 760, height: 476)
    private static let width = (760 - 5 * 10) / 6.0

    private let panel = NSPanel(
        contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
        defer: false)
    private let view = LauncherView()

    private var ids: [String] { view.widgetGrid.shown.map(\.id) }

    init() {
        panel.contentView = view
        view.widgets = (1...7).map(numbered)
        panel.makeFirstResponder(view.field)
    }

    @Test func eachWidgetSitsAtItsOwnSpotAndThePanelKeepsTheRest() {
        view.widgetSpots = [
            "1": .aboveCentre, "2": .leftMiddle, "4": .rightBottom, "5": .rightBottom,
            "6": .leftTop,
        ]
        view.layoutSubtreeIfNeeded()
        #expect(ids == ["3", "7", "1", "6", "2", "4", "5"])
        #expect(
            view.widgetGrid.tiles.map(\.floating) == [false, false]
                + Array(repeating: true, count: 5))
        #expect(
            view.widgetGrid.tiles.prefix(2).allSatisfy { unsafe $0.superview === view.widgetGrid })
        let floats = view.widgetGrid.floats.map(\.frame)
        expect(
            floats[0],
            NSRect(x: 100 + 2.5 * (Self.width + 10), y: 592, width: Self.width, height: 78))
        expect(floats[1], NSRect(x: -140, y: 498, width: 220, height: 78))
        expect(floats[2], NSRect(x: -140, y: 299, width: 220, height: 78))
        expect(floats[3], NSRect(x: 880, y: 188, width: 220, height: 78))
        expect(floats[4], NSRect(x: 880, y: 100, width: 220, height: 78))
        #expect(view.widgetOverhang == 94)
        #expect(view.widgetsFillPanel)
    }

    @Test func groupsAboveSitOnTheSameLastRowOverThePanel() {
        view.widgets = (1...8).map(numbered)
        view.widgetSpots = Dictionary(
            uniqueKeysWithValues: (1...7).map { ("\($0)", .aboveLeft) } + [("8", .aboveRight)])
        let floats = view.widgetGrid.floats.map(\.frame)
        expect(floats[6], NSRect(x: 100, y: 592, width: Self.width, height: 78))
        expect(floats[7], NSRect(x: 860 - Self.width, y: 592, width: Self.width, height: 78))
        #expect(view.widgetOverhang == 182)
    }

    @Test func theStripOnlyLimitsTheWidgetsInThePanel() {
        view.widgets = (1...9).map(numbered)
        view.widgetSpots = ["8": .leftTop, "9": .rightTop]
        view.widgetLayout = .strip
        #expect(ids == ["1", "2", "3", "4", "5", "6", "8", "9"])
        #expect(!view.widgetsFillPanel)
    }

    @Test func withNothingInThePanelItStaysShort() {
        view.widgetSpots = Dictionary(uniqueKeysWithValues: (1...7).map { ("\($0)", .leftTop) })
        view.layoutSubtreeIfNeeded()
        #expect(!view.widgetsFillPanel)
        #expect(view.widgetGrid.frame.height == 0)
        view.widgetSpots = [:]
        #expect(view.widgetsFillPanel)
    }

    @Test func aReorderedSpotIsSavedAgainstTheWidgetsAroundItInTheSameSpot() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        view.widgets = (1...4).map(numbered)
        view.widgetSpots = ["1": .rightTop, "3": .rightTop]
        view.widgetGrid.order = ["2", "4", "3", "1"]
        #expect(view.dropWidget("3"))
        #expect(edits == [.move("3", before: "1")])
        view.widgetGrid.order = ["2", "4", "3", "1"]
        #expect(view.dropWidget("1"))
        #expect(edits.last == .move("1", before: "4"))
    }

    private func expect(
        _ actual: NSRect, _ expected: NSRect, sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let close = [
            (actual.minX, expected.minX), (actual.minY, expected.minY),
            (actual.width, expected.width), (actual.height, expected.height),
        ].allSatisfy { abs($0 - $1) < 1 }
        #expect(close, "\(actual) is not \(expected)", sourceLocation: sourceLocation)
    }

    private func numbered(_ number: Int) -> WidgetGrid.Widget {
        .init(
            id: "\(number)", name: "Widget \(number)", value: "\(number)", detail: "",
            action: "Open \(number)", spoken: "Widget \(number)")
    }
}
