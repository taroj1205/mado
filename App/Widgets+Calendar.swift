import AppCore
import AppKit
import GlassUI

extension Widgets {
    enum Schedule {
        case loading
        case blocked
        case found([CalendarAgenda.Found])
    }

    struct Calendars {
        var schedule = Schedule.loading
        var scheduling: Task<Void, Never>?
        var monthShift = 0
        var monthEvents: [CalendarAgenda.Found] = []
        var monthFetching: Task<Void, Never>?

        mutating func stop() {
            scheduling?.cancel()
            scheduling = nil
            monthFetching?.cancel()
            monthFetching = nil
            monthShift = 0
        }
    }

    static let calendarWidget = "calendar"
    static let upNext = "up_next"
    static let calendarApp = "com.apple.iCal"
    private static let openCalendar = "Open Calendar"
    private static let allowCalendar = "Allow Calendar Access"
    private static let nothingToday = "Nothing else today"

    static func month(
        at date: Date, shift: Int, events: [CalendarAgenda.Found]
    ) -> WidgetGrid.Widget {
        let name = name(of: calendarWidget)
        let shown = Calendar.current.date(byAdding: .month, value: shift, to: date) ?? date
        let spoken =
            shift == 0
            ? date.formatted(date: .complete, time: .omitted)
            : shown.formatted(.dateTime.month(.wide).year())
        return .init(
            id: calendarWidget, name: name,
            content: .month(
                .init(
                    today: Calendar.current.startOfDay(for: date), shift: shift,
                    events: events.map(\.event),
                    colours: Dictionary(
                        events.map { ($0.event.id, $0.colour ?? .controlAccentColor) }
                    ) { first, _ in first })),
            action: openCalendar, spoken: "\(name): \(spoken)", isWide: true, isTall: true)
    }

    static func widget(for schedule: Schedule, at date: Date) -> WidgetGrid.Widget {
        let name = name(of: upNext)
        switch schedule {
        case .loading:
            return .init(
                id: upNext, name: name, content: .loading(title: name), action: openCalendar,
                spoken: "\(name): loading", isWide: true)

        case .blocked:
            return .init(
                id: upNext, name: name,
                content: .permission(
                    title: CalendarAgenda.title, request: "Allow calendar access",
                    reason: "To show your next meeting"),
                action: allowCalendar,
                spoken: "\(name): allow calendar access to show your next meeting", isWide: true)

        case .found(let found):
            return upcoming(in: found, at: date)
        }
    }

    private static func upcoming(
        in found: [CalendarAgenda.Found], at date: Date
    ) -> WidgetGrid.Widget {
        let name = name(of: upNext)
        switch Agenda(events: found.map(\.event)).upNext(at: date, calendar: .current) {
        case .today(let event):
            let hours = (event.start..<event.end).formatted(.interval.hour().minute())
            let detail = [hours, event.place].filter { !$0.isEmpty }.joined(separator: " · ")
            let countdown = Agenda.countdown(to: event.start, at: date)
            let colour = found.first { $0.event.id == event.id }?.colour ?? .controlAccentColor
            return .init(
                id: upNext, name: name,
                content: .event(
                    title: name,
                    .init(
                        title: event.title, countdown: countdown,
                        detail: detail, colour: colour)),
                action: event.meeting == nil
                    ? CalendarAgenda.openTitle : CalendarAgenda.joinTitle,
                spoken: "\(name): \(event.title), \(detail), \(countdown)", isWide: true)

        case .tomorrow(let event):
            let detail =
                event.map { event in
                    "Tomorrow \(event.start.formatted(date: .omitted, time: .shortened)) · "
                        + event.title
                } ?? "Tomorrow is clear"
            return .init(
                id: upNext, name: name,
                content: .notice(title: name, headline: nothingToday, detail: detail),
                action: openCalendar, spoken: "\(name): \(nothingToday). \(detail)",
                isWide: true)
        }
    }

    static func openApp(_ bundleID: String, titled title: String) -> CommandAction {
        CommandAction(id: "open", title: title) {
            guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            else { throw CocoaError(.fileNoSuchFile) }
            _ = try await NSWorkspace.shared.openApplication(
                at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func refreshSchedule(in view: LauncherView) {
        calendars.scheduling?.cancel()
        calendars.scheduling = nil
        guard shown.contains(Self.upNext) else { return }
        guard CalendarAgenda.hasAccess else {
            calendars.schedule = .blocked
            return
        }
        calendars.scheduling = Task { [weak self, weak view] in
            let found = await CalendarAgenda.upNext(around: .now)
            guard !Task.isCancelled, let self, let view else { return }
            calendars.schedule = .found(found)
            refresh(view)
        }
    }

    func page(_ page: WidgetGrid.Page, in view: LauncherView) {
        switch page {
        case .previous: calendars.monthShift -= 1
        case .next: calendars.monthShift += 1
        case .today: calendars.monthShift = 0
        }
        refresh(view)
        refreshMonth(in: view)
    }

    func refreshCalendars(in view: LauncherView) {
        refreshSchedule(in: view)
        refreshMonth(in: view)
    }

    private func refreshMonth(in view: LauncherView) {
        calendars.monthFetching?.cancel()
        calendars.monthFetching = nil
        let shift = calendars.monthShift
        guard shown.contains(Self.calendarWidget), CalendarAgenda.hasAccess,
            let day = Calendar.current.date(byAdding: .month, value: shift, to: .now)
        else {
            calendars.monthEvents = []
            return
        }
        calendars.monthFetching = Task { [weak self, weak view] in
            let found = await CalendarAgenda.month(around: day)
            guard !Task.isCancelled, let self, let view else { return }
            calendars.monthEvents = found
            refresh(view)
        }
    }

    func upNextAction(titled title: String) -> CommandAction {
        switch calendars.schedule {
        case .loading:
            return Self.openApp(Self.calendarApp, titled: title)

        case .blocked:
            return CalendarAgenda.allow(titled: title)

        case .found(let found):
            let upcoming = Agenda(events: found.map(\.event)).upNext(at: .now, calendar: .current)
            guard case .today(let event) = upcoming,
                let picked = found.first(where: { $0.event.id == event.id })
            else { return Self.openApp(Self.calendarApp, titled: title) }
            return event.meeting.map(CalendarAgenda.join) ?? CalendarAgenda.open(picked)
        }
    }
}
