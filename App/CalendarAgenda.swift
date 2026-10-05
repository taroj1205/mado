import AppCore
import AppKit
import EventKit
import GlassUI
import SearchKit

@MainActor
final class CalendarAgenda {
    struct Found: Sendable {
        let event: Agenda.Event
        let colour: NSColor?
        let calendarID: String
        let uid: String
    }

    private struct Listed {
        var headings: [Agenda.Heading] = []
        var now = Date.now
        var agenda = Agenda(events: [])
        var found: [String: Found] = [:]
        var shown: [String: Found] = [:]
        var days: [String: Date] = [:]
    }

    private enum Failure: Error {
        case joinFailed
    }

    private actor Events {
        private lazy var store = EKEventStore()

        func found(in span: DateInterval) -> [Found] {
            let predicate = store.predicateForEvents(
                withStart: span.start, end: span.end, calendars: nil)
            let found = store.events(matching: predicate)
                .filter { $0.status != .canceled }
                .map { source in
                    Found(
                        event: CalendarAgenda.event(from: source), colour: source.calendar?.color,
                        calendarID: source.calendar?.calendarIdentifier ?? "",
                        uid: source.calendarItemExternalIdentifier ?? "")
                }
            return Array(Dictionary(found.map { ($0.event.id, $0) }) { first, _ in first }.values)
        }

        func requestAccess() async throws {
            _ = try await store.requestFullAccessToEvents()
        }
    }

    static let title = "Calendar"
    static let symbol = "calendar"
    static let moduleID = "notes"
    static let joinKeys = ["⌘", "J"]
    private static let prefix = "agenda."
    private static let allowID = "agenda.allow"
    private static let upNextDays = 2
    static let joinTitle = "Join Meeting"
    static let openTitle = "Open in Calendar"
    private static let events = Events()

    static var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    private var listed = Listed()

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(prefix)
    }

    static func isOn(in modules: ModuleManager?) -> Bool {
        modules?.isEnabled(moduleID) != false
    }

    nonisolated private static func id(of event: EKEvent) -> String {
        let id = event.eventIdentifier ?? event.calendarItemIdentifier
        return "\(id)@\(event.startDate.timeIntervalSince1970)"
    }

    nonisolated private static func event(from source: EKEvent) -> Agenda.Event {
        let attendees = (source.attendees ?? [])
            .filter { !$0.isCurrentUser }
            .map { $0.name ?? $0.url.absoluteString.replacingOccurrences(of: "mailto:", with: "") }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        let texts = [source.url?.absoluteString, source.location, source.notes].compactMap(\.self)
        return Agenda.Event(
            id: id(of: source), title: source.title ?? "", start: source.startDate,
            end: source.endDate, isAllDay: source.isAllDay, location: source.location ?? "",
            attendees: attendees, meeting: Meeting(in: texts))
    }

    private static func item(
        id: String, for found: Found, time: String, detail: String, joins: Bool
    ) -> ResultList.Item {
        let event = found.event
        var item = ResultList.Item(
            id: id, title: event.title, subtitle: detail, kind: "", symbol: "",
            action: event.meeting == nil ? openTitle : joinTitle,
            shortcut: joins ? joinKeys : [])
        item.event = ResultList.Event(
            time: time, colour: found.colour ?? .controlAccentColor,
            hasMeeting: event.meeting != nil)
        return item
    }

    static func allow(titled title: String) -> CommandAction {
        CommandAction(id: "allow", title: title) {
            guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .calendars))
                return
            }
            try await events.requestAccess()
        }
    }

    static func upNext(around now: Date) async -> [Found] {
        let today = Calendar.current.startOfDay(for: now)
        guard let end = Calendar.current.date(byAdding: .day, value: upNextDays, to: today)
        else { return [] }
        return await events.found(in: DateInterval(start: today, end: end))
    }

    static func open(_ found: Found) -> CommandAction {
        CommandAction(id: "open", title: openTitle) {
            try show(found)
        }
    }

    static func join(_ meeting: Meeting) -> CommandAction {
        CommandAction(id: "join", title: joinTitle) {
            guard NSWorkspace.shared.open(meeting.url) else { throw Failure.joinFailed }
        }
    }

    private static func show(_ found: Found) throws {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: found.event.start)
        let quoted = { (text: String) in
            text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
        }
        try SystemCommands.runScript(
            """
            tell application "Calendar"
                activate
                switch view to day view
                set shown to current date
                set day of shown to 1
                set year of shown to \(day.year ?? 0)
                set month of shown to \(day.month ?? 1)
                set day of shown to \(day.day ?? 1)
                view calendar at shown
                try
                    show event id "\(quoted(found.uid))" ¬
                        of calendar id "\(quoted(found.calendarID))"
                end try
            end tell
            """)
    }

    static func headings(for query: String, at now: Date) -> [Agenda.Heading] {
        let calendar = Calendar.current
        if Agenda.matches(query) {
            return Agenda.upcoming(at: now, calendar: calendar)
        }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        return DayQuery.day(in: query, now: now, calendar: gregorian).map { day in
            [Agenda.heading(for: day, at: now, calendar: calendar)]
        } ?? []
    }

    private static func notice(for headings: [Agenda.Heading]) -> ResultList.Notice {
        guard headings.count == 1, let day = headings.first else {
            return ResultList.Notice(
                title: "No events today or tomorrow", detail: "Events in Calendar show up here.")
        }
        let date = Agenda.date(of: day.start, calendar: .current)
        return ResultList.Notice(
            title: "No events on \(date)", detail: "Events in Calendar show up here.")
    }

    func sections(for headings: [Agenda.Heading], at now: Date) async -> [ResultList.Section] {
        listed = Listed(headings: headings, now: now)
        guard Self.hasAccess else {
            let request = ResultList.Item(
                id: Self.allowID, title: "Allow Calendar Access",
                subtitle: "Mado lists the day’s events here.", kind: "", symbol: Self.symbol,
                action: "Allow")
            return [ResultList.Section(title: Self.title, items: [request])]
        }
        let calendar = Calendar.current
        guard let span = Agenda.span(of: headings, calendar: calendar) else { return [] }
        let fetched = await Self.events.found(in: span)
        guard !Task.isCancelled else { return [] }
        let found = Dictionary(uniqueKeysWithValues: fetched.map { ($0.event.id, $0) })
        let agenda = Agenda(events: found.values.map(\.event))
        listed = Listed(headings: headings, now: now, agenda: agenda, found: found)
        let days = agenda.days(under: headings, calendar: calendar)
        guard days.contains(where: { !$0.events.isEmpty }) else {
            return [ResultList.Section(title: "", items: [], notice: Self.notice(for: headings))]
        }
        return rows(for: days, of: agenda, at: now, calendar: calendar)
    }

    func month(for item: ResultList.Item?) -> LauncherView.CalendarMonth? {
        guard let first = listed.headings.first?.start else { return nil }
        let day = item.flatMap { listed.days[$0.id] } ?? first
        let colours = listed.found.mapValues { $0.colour ?? .controlAccentColor }
        return listed.agenda.month(showing: day, at: listed.now, calendar: .current).map { month in
            LauncherView.CalendarMonth(month: month, colours: colours)
        }
    }

    private func rows(
        for days: [Agenda.Day], of agenda: Agenda, at now: Date, calendar: Calendar
    ) -> [ResultList.Section] {
        let next = agenda.next(at: now)
        let meeting = agenda.nextMeeting(at: now)
        let first = days.first?.start ?? now
        var preferred = false
        return days.enumerated().map { index, day in
            let items = day.events.compactMap { event -> ResultList.Item? in
                guard let source = listed.found[event.id] else { return nil }
                let id = "\(Self.prefix)\(index).\(event.id)"
                listed.shown[id] = source
                listed.days[id] = day.start
                var row = Self.item(
                    id: id, for: source,
                    time: Agenda.time(of: event, listedFrom: first, calendar: calendar),
                    detail: agenda.detail(of: event, at: now), joins: event == meeting)
                row.isDimmed = event.hasEnded(at: now)
                row.prefersSelection = !preferred && event == next
                preferred = preferred || row.prefersSelection
                return row
            }
            return ResultList.Section(title: day.title, items: items)
        }
    }

    func actions(for id: String) -> [(action: CommandAction, keys: [String])] {
        if id == Self.allowID {
            return [(Self.allow(titled: "Allow"), LauncherView.Action.primaryKeys)]
        }
        guard let picked = listed.shown[id] else { return [] }
        let open = Self.open(picked)
        guard let meeting = picked.event.meeting else {
            return [(open, LauncherView.Action.primaryKeys)]
        }
        return [
            (Self.join(meeting), LauncherView.Action.primaryKeys),
            (open, LauncherView.Action.secondaryKeys),
        ]
    }
}
