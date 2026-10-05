import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetCalendarTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let month: AgendaMonth
    private let calendar: WidgetGrid.Widget
    private let upNext = WidgetGrid.Widget(
        id: "up_next", name: "Up Next",
        content: .event(
            title: "Up Next",
            .init(
                title: "Design review", countdown: "in 25 min", detail: "2:30 – 3:00 PM · Zoom",
                colour: .systemOrange)),
        action: "Join Meeting", spoken: "Up Next: Design review", isWide: true)

    init() throws {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.locale = Locale(identifier: "en_NZ")
        gregorian.firstWeekday = 2
        let day = try #require(gregorian.date(from: DateComponents(year: 2_026, month: 9, day: 30)))
        month = try #require(Agenda(events: []).month(showing: day, at: day, calendar: gregorian))
        calendar = .init(
            id: "calendar", name: "Calendar", content: .month(month), action: "Open Calendar",
            spoken: "Calendar", isWide: true, isTall: true)
        panel.contentView = view
        view.widgets = [
            calendar, upNext, small("weather"), small("clock"), wide("music"), small("battery"),
            small("system"),
        ]
    }

    @Test func theCalendarTakesTwoRowsAndTheRestFlowBesideIt() {
        view.layoutSubtreeIfNeeded()
        let frames = view.widgetGrid.tiles.map(\.frame)
        let column = (732 - 5 * 8) / 6.0
        let columns: [CGFloat] = [0, 2, 4, 5, 2, 4, 5]
        let rows: [CGFloat] = [0, 0, 0, 0, 1, 1, 1]
        for (frame, (start, row)) in zip(frames, zip(columns, rows)) {
            #expect(abs(frame.minX - 14 - start * (column + 8)) < 0.01)
            #expect(frame.minY == 12 + row * (78 + 8))
        }
        #expect(abs(frames[0].width - (2 * column + 8)) < 0.01)
        #expect(frames[0].height == 164)
        #expect(frames[1...].allSatisfy { $0.height == 78 })
        #expect(abs(view.widgetGrid.frame.height - (12 + 78 + 8 + 78 + 4)) < 0.01)
    }

    @Test func theStripLeavesTheCalendarOutAndRefusesToTakeIt() {
        view.widgetLayout = .strip
        #expect(view.widgetGrid.shown.map(\.id) == ["up_next", "weather", "clock", "music"])
        view.widgetSpots = ["calendar": .leftTop]
        #expect(!view.widgetGrid.accepts("calendar", at: .panel, before: nil))
        #expect(view.widgetGrid.accepts("system", at: .rightTop, before: nil))
    }

    @Test func aSideRailStacksTheCalendarAtItsFullHeight() {
        let screen = CGRect(x: 400, y: 200, width: 760, height: 548)
        let frames = WidgetGrid.floatingFrames(
            of: [(calendar, .leftTop), (upNext, .leftTop), (small("clock"), .rightMiddle)],
            beside: screen)
        #expect(frames[0] == CGRect(x: 400 - 20 - 220, y: 748 - 166, width: 220, height: 166))
        #expect(
            frames[1] == CGRect(x: 400 - 20 - 220, y: 748 - 166 - 10 - 78, width: 220, height: 78))
        #expect(frames[2] == CGRect(x: 1_180, y: 474 - 39, width: 220, height: 78))
    }

    @Test func aboveThePanelTheCalendarSpansBothShelfRows() {
        let screen = CGRect(x: 400, y: 200, width: 760, height: 548)
        let frames = WidgetGrid.floatingFrames(
            of: [(calendar, .aboveLeft), (small("clock"), .aboveLeft)], beside: screen)
        let base = 748 + WidgetGrid.lift
        #expect(frames[0].minY == base && frames[0].height == 166)
        #expect(frames[1].minY == base + 78 + 10 && frames[1].height == 78)
        #expect(frames[1].minX > frames[0].maxX)
        #expect(WidgetGrid.shelfRows(of: [(calendar, .aboveLeft)]) == 2)
    }

    @Test func theMonthTileDrawsTheMonthAndNothingElse() throws {
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(!tile.month.isHidden)
        #expect(tile.month.month == month)
        #expect(!tile.lines.arrangedSubviews.contains { !$0.isHidden })
        #expect(tile.countdown.stringValue.isEmpty)
        let inside = tile.bounds.insetBy(dx: 12, dy: 10)
        let shown = tile.convert(tile.month.bounds, from: tile.month)
        #expect(abs(shown.minX - inside.minX) < 1 && abs(shown.maxX - inside.maxX) < 1)
        #expect(shown.minY == inside.minY && shown.maxY == inside.maxY)
    }

    @Test func upNextShowsTheCountdownTheEventAndItsTimeAndService() {
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        #expect(tile.month.isHidden)
        #expect(tile.title.stringValue == "UP NEXT")
        #expect(tile.countdown.stringValue == "in 25 min")
        #expect(tile.headline.stringValue.hasSuffix("Design review"))
        #expect(tile.headline.attributedStringValue.containsAttachments)
        #expect(tile.detail.stringValue == "2:30 – 3:00 PM · Zoom")
        #expect(
            tile.lines.arrangedSubviews.filter { !$0.isHidden } == [
                tile.title, tile.headline, tile.detail,
            ])
        let title = tile.convert(
            tile.title.alignmentRect(forFrame: tile.title.bounds), from: tile.title)
        let countdown = tile.countdown.alignmentRect(forFrame: tile.countdown.frame)
        #expect(abs(tile.bounds.maxX - countdown.maxX - 12) <= 1)
        #expect(title.maxX <= countdown.minX)
    }

    @Test func aTileThatStopsShowingAnEventOrMonthDropsThem() {
        view.layoutSubtreeIfNeeded()
        let tiles = view.widgetGrid.tiles
        view.widgets = [
            .init(
                id: "calendar", name: "Calendar", content: .loading(title: "Calendar"),
                action: "Open Calendar", spoken: "Calendar", isWide: true, isTall: true),
            .init(
                id: "up_next", name: "Up Next",
                content: .notice(
                    title: "Up Next", headline: "Nothing else today", detail: "Tomorrow is clear"),
                action: "Open Calendar", spoken: "Up Next", isWide: true),
            small("weather"), small("clock"), wide("music"), small("battery"), small("system"),
        ]
        #expect(view.widgetGrid.tiles == tiles)
        #expect(tiles[0].month.isHidden)
        #expect(tiles[1].countdown.stringValue.isEmpty)
        #expect(tiles[1].headline.stringValue == "Nothing else today")
        #expect(!tiles[1].headline.attributedStringValue.containsAttachments)
    }

    @Test func theGalleryCardForTheCalendarIsTwoRowsTall() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600), styleMask: [.borderless],
            backing: .buffered, defer: true)
        window.isReleasedWhenClosed = false
        let gallery = WidgetGallery()
        window.contentView = gallery
        gallery.catalogue =
            [
                .init(
                    id: "calendar", name: "Calendar", summary: "Month and today", group: .today,
                    isWide: true, isTall: true)
            ]
            + ["a", "b", "c", "d", "e"].map { .init(id: $0, name: $0, summary: "", group: .today) }
        gallery.layoutSubtreeIfNeeded()
        let cards = gallery.cards
        #expect(cards[0].tile.frame.height == 164)
        #expect(cards[0].frame.minY == cards[1].frame.minY)
        #expect(cards[0].frame.maxY == cards[5].frame.maxY)
        #expect(cards[5].frame.minX == cards[1].frame.minX)
        window.close()
    }

    private func small(_ id: String) -> WidgetGrid.Widget {
        .init(id: id, name: id, value: id, detail: "", action: "Open \(id)", spoken: id)
    }

    private func wide(_ id: String) -> WidgetGrid.Widget {
        .init(
            id: id, name: id, content: .value(id, detail: ""), action: "Open \(id)", spoken: id,
            isWide: true)
    }
}
