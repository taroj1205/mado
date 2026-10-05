import AppCore
import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct CalendarLayoutTests {
    private static let answerRow = 1
    private static let eventRow = 3

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.reducesMotion = { true }
    }

    private static func answer() -> ResultList.Section {
        let item = ResultList.Item(
            id: "calculator", title: "In 2 days", subtitle: "From Mon, 5 Oct 2026", kind: "Dates",
            symbol: "", action: "Copy Answer",
            answer: .init(value: "7 Oct 2026", detail: "Wednesday"))
        return .init(title: "Dates", items: [item])
    }

    private static func events() -> ResultList.Section {
        var item = ResultList.Item(
            id: "agenda.0.party", title: "Team dinner", subtitle: "Harbour Kitchen", kind: "",
            symbol: "", action: "Open in Calendar")
        item.event = .init(time: "18:00", colour: .systemPurple, hasMeeting: false)
        return .init(title: "Wed, Oct 7 · In 2 days", items: [item])
    }

    private static func month() throws -> LauncherView.CalendarMonth {
        let day = Date(timeIntervalSince1970: 1_791_000_000)
        let month = try #require(
            Agenda(events: []).month(showing: day, at: day, calendar: .current))
        return .init(month: month, colours: [:])
    }

    private func showCalendar(_ sections: [ResultList.Section]) throws {
        let shown = try Self.month()
        view.showCalendar { _ in shown }
        view.show(sections)
        view.layoutSubtreeIfNeeded()
    }

    @Test func theAnswerSpansThePanelAndTheMonthSitsUnderIt() throws {
        var fits = 0
        view.onFit = { fits += 1 }

        try showCalendar([Self.answer(), Self.events()])

        let table = view.results.table
        let card = try #require(
            table.view(atColumn: 0, row: Self.answerRow, makeIfNecessary: true) as? AnswerCell)
        let event = try #require(
            table.view(atColumn: 0, row: Self.eventRow, makeIfNecessary: true) as? EventCell)
        #expect(view.results.selectedItem?.id == "calculator")
        #expect(card.frame.width == table.bounds.width)
        #expect(event.frame.width == table.bounds.width - CalendarPane.width)
        #expect(view.results.scrollerInsets.right == CalendarPane.width)
        let below =
            ResultList.topInset + ResultList.headerHeight + ResultList.answerHeight
            + 2 * ResultList.rowGap
        #expect(view.results.belowAnswer == below)
        #expect(view.calendarPane.frame.minX == view.bounds.width - CalendarPane.width)
        #expect(view.calendarPane.frame.maxX == view.bounds.width)
        #expect(view.calendarPane.frame.maxY == view.results.frame.maxY - below)
        #expect(view.calendarPane.frame.minY == 0)
        #expect(view.showsCalendarAnswer && fits == 1)
    }

    @Test func aDayWithoutAnAnswerStartsTheMonthAtTheTopOfTheList() throws {
        var fits = 0
        view.onFit = { fits += 1 }

        try showCalendar([Self.events()])

        #expect(view.results.belowAnswer == ResultList.topInset)
        #expect(view.calendarPane.frame.maxY == view.results.frame.maxY - ResultList.topInset)
        #expect(!view.showsCalendarAnswer && fits == 0)
    }

    @Test func leavingTheCalendarGivesTheRowsTheirWidthBack() throws {
        var fits = 0
        view.onFit = { fits += 1 }
        try showCalendar([Self.answer(), Self.events()])

        view.showCalendar(nil)
        view.show([Self.events()])
        view.layoutSubtreeIfNeeded()

        let event = try #require(
            view.results.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? EventCell)
        #expect(view.calendarPane.isHidden)
        #expect(event.frame.width == view.results.table.bounds.width)
        #expect(view.results.scrollerInsets.right == 0)
        #expect(!view.showsCalendarAnswer && fits == 2)
    }
}
