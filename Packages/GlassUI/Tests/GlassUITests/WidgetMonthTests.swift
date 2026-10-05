import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetMonthTests {
    private struct MissingDay: Error {}

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let today: Date

    private var tile: WidgetTile { view.widgetGrid.tiles[0] }

    init() throws {
        today = try #require(
            Calendar.current.date(from: DateComponents(year: 2_026, month: 9, day: 30)))
        panel.contentView = view
        show()
    }

    private func show(
        shift: Int = 0, events: [Agenda.Event] = [], searchesDays: Bool = false, day: Date? = nil
    ) {
        view.widgets = [
            .init(
                id: "calendar", name: "Calendar",
                content: .month(
                    .init(
                        today: today, shift: shift, events: events, searchesDays: searchesDays,
                        day: day)),
                action: "Open Calendar", spoken: "Calendar", isWide: true, isTall: true)
        ]
        view.layoutSubtreeIfNeeded()
    }

    private func point(of day: Int) throws -> NSPoint {
        let month = tile.month
        for row in 0..<Int(month.bounds.height) {
            for column in 0..<Int(month.bounds.width) {
                let point = NSPoint(x: column, y: row)
                guard case .day(let index) = month.hit(at: point),
                    let shown = month.month?.days[index]
                else { continue }
                if shown.isInMonth, shown.number == "\(day)" { return point }
            }
        }
        throw MissingDay()
    }

    private func click(_ point: NSPoint, count: Int = 1) throws {
        let location = tile.month.convert(point, to: nil)
        let event = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: location, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: count,
                pressure: 1))
        tile.mouseDown(with: event)
    }

    private func pointer() throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 0,
                pressure: 0))
    }

    private func controls() -> [WidgetGrid.Page] {
        let month = tile.month
        var found: [WidgetGrid.Page] = []
        for column in 0..<Int(month.bounds.width) {
            let hit = month.hit(at: NSPoint(x: column, y: 7))
            if case .page(let page) = hit, !found.contains(page) {
                found.append(page)
            }
        }
        return found
    }

    private func dayStart(_ day: Int) throws -> Date {
        try #require(
            Calendar.current.date(from: DateComponents(year: 2_026, month: 9, day: day)))
    }

    @Test func clickingADayAsksForThatDayWithoutTouchingTheSearchField() throws {
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        try click(point(of: 15))
        #expect(seen == [.day(try dayStart(15))])
        #expect(queries.isEmpty)
        #expect(view.field.stringValue.isEmpty)
        #expect(!tile.month.showsDay)
    }

    @Test func aPickedDayReplacesTheGridWithThatDaysEvents() throws {
        let start = try #require(
            Calendar.current.date(from: DateComponents(year: 2_026, month: 9, day: 15, hour: 10)))
        let event = Agenda.Event(
            id: "a", title: "Review", start: start, end: start.addingTimeInterval(3_600))
        show(events: [event], day: try dayStart(15))
        #expect(tile.month.showsDay)
        #expect(tile.month.dayPage.day?.events.map(\.title) == ["Review"])
        #expect(tile.month.dayPage.day?.number == "15")
        show(events: [event])
        #expect(!tile.month.showsDay)
    }

    @Test func aDayOutsideTheShownMonthLeavesTheGridInPlace() {
        show(day: Calendar.current.date(byAdding: .year, value: 1, to: today))
        #expect(!tile.month.showsDay)
    }

    @Test func theDayViewHasABackButtonAndStepsByDay() throws {
        show(day: try dayStart(15))
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        #expect(tile.month.hit(at: NSPoint(x: 6, y: 6)) == .page(.month))
        #expect(tile.month.hit(at: NSPoint(x: 100, y: 80)) == nil)
        try click(NSPoint(x: 6, y: 6))
        #expect(seen == [.month])
        let names = tile.accessibilityCustomActions()?.map(\.name)
        #expect(names == ["Previous Day", "Next Day", "Back to Month", "Today"])
    }

    @Test func theDayViewOffersTodayOnlyAwayFromToday() throws {
        show(day: try dayStart(30))
        #expect(!controls().contains(.today))
        show(day: try dayStart(15))
        #expect(controls().contains(.today))
    }

    @Test func clickingADayAsksForThatDayInTheSearchFieldWhenSettingSaysSo() throws {
        show(searchesDays: true)
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        try click(point(of: 15))
        #expect(view.field.stringValue == "15 sep 2026")
        #expect(queries == ["15 sep 2026"])
    }

    @Test func doubleClickingTheTitleOpensTheCalendar() throws {
        var opened: [String] = []
        view.onWidget = { opened.append($0.id) }
        try click(NSPoint(x: 1, y: 1))
        #expect(opened.isEmpty)
        try click(NSPoint(x: 1, y: 1), count: 2)
        #expect(opened == ["calendar"])
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func theArrowsOnlyExistWhileThePointerIsOverTheTile() throws {
        #expect(controls().isEmpty)
        tile.month.mouseMoved(with: try pointer())
        #expect(controls() == [.previous, .next])
        tile.month.mouseExited(with: try pointer())
        #expect(controls().isEmpty)
    }

    @Test func theArrowsPageTheMonthAndSelectTheTile() throws {
        tile.month.mouseMoved(with: try pointer())
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        let month = tile.month
        try click(NSPoint(x: month.bounds.maxX - 10, y: 7))
        try click(NSPoint(x: month.bounds.maxX - 34, y: 7))
        #expect(seen == [.next, .previous])
        #expect(view.selectedWidget == 0)
    }

    @Test func aMonthAwayFromTodayOffersTheWayBack() {
        #expect(!controls().contains(.today))
        show(shift: 2)
        #expect(controls().contains(.today))
        #expect(tile.month.month?.name != WidgetGrid.Month(today: today).grid(in: .current)?.name)
        let names = tile.accessibilityCustomActions()?.map(\.name)
        #expect(names == ["Previous Month", "Next Month", "Today"])
        show()
        #expect(tile.accessibilityCustomActions()?.map(\.name) == ["Previous Month", "Next Month"])
    }

    @Test func dotsMarkTheDaysThatHaveEvents() throws {
        let start = try #require(
            Calendar.current.date(from: DateComponents(year: 2_026, month: 9, day: 12, hour: 10)))
        let event = Agenda.Event(
            id: "a", title: "Review", start: start, end: start.addingTimeInterval(3_600))
        show(events: [event])
        let days = try #require(tile.month.month?.days)
        #expect(days.filter { !$0.events.isEmpty }.map(\.number) == ["12"])
    }

    @Test func daysStayInertWhenTheCalendarModuleIsOff() throws {
        let inside = try point(of: 15)
        view.widgets = [
            .init(
                id: "calendar", name: "Calendar",
                content: .month(.init(today: today, opensDays: false)),
                action: "Open Calendar", spoken: "Calendar", isWide: true, isTall: true)
        ]
        view.layoutSubtreeIfNeeded()
        var opened: [String] = []
        view.onWidget = { opened.append($0.id) }
        try click(inside, count: 2)
        #expect(tile.month.hit(at: inside) == nil)
        #expect(view.field.stringValue.isEmpty)
        #expect(opened == ["calendar"])
        tile.month.mouseMoved(with: try pointer())
        #expect(controls() == [.previous, .next])
    }

    @Test func aTileNobodyWiredUpIgnoresThePointer() {
        let loose = WidgetTile(floating: false)
        loose.show(
            .init(
                id: "calendar", name: "Calendar", content: .month(.init(today: today)),
                action: "Open Calendar", spoken: "Calendar", isWide: true, isTall: true))
        loose.frame = NSRect(x: 0, y: 0, width: 240, height: 164)
        loose.layoutSubtreeIfNeeded()
        #expect(!loose.month.isInteractive)
        #expect(loose.month.hit(at: NSPoint(x: 100, y: 60)) == nil)
        #expect(loose.accessibilityCustomActions()?.isEmpty ?? true)
    }

    @Test func editingTurnsTheTileBackIntoSomethingToArrange() {
        #expect(tile.month.isInteractive)
        tile.editing = true
        #expect(!tile.month.isInteractive)
        #expect(tile.month.hit(at: NSPoint(x: 100, y: 60)) == nil)
        tile.editing = false
        #expect(tile.month.isInteractive)
    }

    @Test func aSwipePagesOnceAndAWheelNotchPagesEachTime() throws {
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        tile.scrollWheel(with: try wheel(-40))
        tile.scrollWheel(with: try wheel(40))
        tile.scrollWheel(with: try wheel(-10))
        #expect(seen == [.next, .previous])
    }

    @Test func commandArrowsPageTheSelectedCalendar() throws {
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        view.selectWidget(0)
        #expect(view.handleModifiedKey(try arrow("\u{F703}")))
        #expect(view.handleModifiedKey(try arrow("\u{F702}")))
        #expect(seen == [.next, .previous])
    }

    @Test func mouseWheelStepsOnEveryNotch() throws {
        var seen: [WidgetGrid.Page] = []
        view.onPage = { seen.append($0) }
        let notch = try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: -1, wheel2: 0,
                wheel3: 0
            )
            .flatMap(NSEvent.init))
        tile.scrollWheel(with: notch)
        tile.scrollWheel(with: notch)
        #expect(seen == [.next, .next])
    }

    private func wheel(_ delta: Int32) throws -> NSEvent {
        try #require(
            CGEvent(
                scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: delta,
                wheel2: 0, wheel3: 0
            )
            .flatMap(NSEvent.init))
    }

    private func arrow(_ key: String) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: key,
                charactersIgnoringModifiers: key, isARepeat: false, keyCode: 0))
    }
}
