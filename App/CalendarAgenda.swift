import AppCore
import AppKit
import EventKit
import GlassUI

@MainActor
final class CalendarAgenda {
    private struct Found: Sendable {
        let event: Agenda.Event
        let colour: NSColor?
        let calendarID: String
        let uid: String
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
    private static let joinTitle = "Join Meeting"
    private static let openTitle = "Open in Calendar"

    private let events = Events()
    private var shown: [String: Found] = [:]

    private var allow: CommandAction {
        CommandAction(id: "allow", title: "Allow") { [weak self] in
            guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .calendars))
                return
            }
            try await self?.events.requestAccess()
        }
    }

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

    func sections(at now: Date) async -> [ResultList.Section] {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            let request = ResultList.Item(
                id: Self.allowID, title: "Allow Calendar Access",
                subtitle: "Mado lists today’s and tomorrow’s events here.", kind: "",
                symbol: Self.symbol, action: "Allow")
            return [ResultList.Section(title: Self.title, items: [request])]
        }
        let calendar = Calendar.current
        guard let span = Agenda.span(around: now, calendar: calendar) else { return [] }
        let fetched = await events.found(in: span)
        guard !Task.isCancelled else { return [] }
        let found = Dictionary(uniqueKeysWithValues: fetched.map { ($0.event.id, $0) })
        let agenda = Agenda(events: found.values.map(\.event))
        let days = agenda.days(at: now, calendar: calendar)
        guard days.contains(where: { !$0.events.isEmpty }) else {
            let notice = ResultList.Notice(
                title: "No events today or tomorrow", detail: "Events in Calendar show up here.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let next = agenda.next(at: now)
        let meeting = agenda.nextMeeting(at: now)
        var listed: [String: Found] = [:]
        var preferred = false
        let sections = days.enumerated().map { index, day in
            let items = day.events.compactMap { event -> ResultList.Item? in
                guard let source = found[event.id] else { return nil }
                let id = "\(Self.prefix)\(index).\(event.id)"
                listed[id] = source
                var row = Self.item(
                    id: id, for: source, time: Agenda.time(of: event, at: now, calendar: calendar),
                    detail: agenda.detail(of: event, at: now), joins: event == meeting)
                row.isDimmed = event.hasEnded(at: now)
                row.prefersSelection = !preferred && event == next
                preferred = preferred || row.prefersSelection
                return row
            }
            return ResultList.Section(title: day.title, items: items)
        }
        shown = listed
        return sections
    }

    func actions(for id: String) -> [(action: CommandAction, keys: [String])] {
        if id == Self.allowID {
            return [(allow, LauncherView.Action.primaryKeys)]
        }
        guard let picked = shown[id] else { return [] }
        let open = CommandAction(id: "open", title: Self.openTitle) {
            try Self.show(picked)
        }
        guard let meeting = picked.event.meeting else {
            return [(open, LauncherView.Action.primaryKeys)]
        }
        let join = CommandAction(id: "join", title: Self.joinTitle) {
            guard NSWorkspace.shared.open(meeting.url) else { throw Failure.joinFailed }
        }
        return [(join, LauncherView.Action.primaryKeys), (open, LauncherView.Action.secondaryKeys)]
    }
}
