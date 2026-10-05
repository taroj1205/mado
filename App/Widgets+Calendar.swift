import AppCore
import AppKit
import GlassUI

extension Widgets {
    enum Schedule {
        case loading
        case blocked
        case found([CalendarAgenda.Found])
    }

    static let calendarWidget = "calendar"
    static let upNext = "up_next"
    static let calendarApp = "com.apple.iCal"
    private static let openCalendar = "Open Calendar"
    private static let allowCalendar = "Allow Calendar Access"
    private static let nothingToday = "Nothing else today"

    static func month(at date: Date) -> WidgetGrid.Widget {
        let name = name(of: calendarWidget)
        return .init(
            id: calendarWidget, name: name,
            content: Agenda(events: []).month(showing: date, at: date, calendar: .current)
                .map(WidgetGrid.Content.month) ?? .loading(title: name),
            action: openCalendar,
            spoken: "\(name): \(date.formatted(date: .complete, time: .omitted))", isWide: true,
            isTall: true)
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
                spoken: "\(name): \(event.title), \(hours), \(countdown)", isWide: true)

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

    func refreshSchedule(in view: LauncherView) {
        scheduling?.cancel()
        scheduling = nil
        guard shown.contains(Self.upNext) else { return }
        guard CalendarAgenda.hasAccess else {
            schedule = .blocked
            return
        }
        scheduling = Task { [weak self, weak view] in
            let found = await CalendarAgenda.upNext(around: .now)
            guard !Task.isCancelled, let self, let view else { return }
            schedule = .found(found)
            refresh(view)
        }
    }

    func upNextAction(titled title: String) -> CommandAction {
        switch schedule {
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
