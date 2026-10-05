import AppCore
import AppKit
import EventKit
import GlassUI

@MainActor
final class CalendarAgenda {
    private struct Shown {
        let event: Agenda.Event
        let source: EKEvent
    }

    static let title = "Calendar"
    static let symbol = "calendar"
    static let moduleID = "notes"
    static let joinKeys = ["⌘", "J"]
    private static let prefix = "agenda."
    private static let allowID = "agenda.allow"
    private static let joinTitle = "Join Meeting"
    private static let openTitle = "Open in Calendar"

    private lazy var store = EKEventStore()
    private var shown: [String: Shown] = [:]

    private var allow: CommandAction {
        CommandAction(id: "allow", title: "Allow") { [weak self] in
            guard EKEventStore.authorizationStatus(for: .event) == .notDetermined else {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .calendars))
                return
            }
            _ = try await self?.store.requestFullAccessToEvents()
        }
    }

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(prefix)
    }

    static func isOn(in modules: ModuleManager?) -> Bool {
        modules?.isEnabled(moduleID) != false
    }

    private static func id(of event: EKEvent) -> String {
        let id = event.eventIdentifier ?? event.calendarItemIdentifier
        return "\(id)@\(event.startDate.timeIntervalSince1970)"
    }

    private static func event(from source: EKEvent) -> Agenda.Event {
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
        id: String, for event: Agenda.Event, detail: String, colour: NSColor?, joins: Bool
    ) -> ResultList.Item {
        var item = ResultList.Item(
            id: id, title: event.title, subtitle: detail, kind: "", symbol: "",
            action: event.meeting == nil ? openTitle : joinTitle,
            shortcut: joins ? joinKeys : [])
        item.event = ResultList.Event(
            time: event.isAllDay
                ? "All day" : event.start.formatted(date: .omitted, time: .shortened),
            colour: colour ?? .controlAccentColor, hasMeeting: event.meeting != nil)
        return item
    }

    private static func show(_ event: EKEvent) throws {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: event.startDate)
        let quoted = { (text: String?) in
            (text ?? "").replacingOccurrences(of: "\\", with: "\\\\")
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
                    show event id "\(quoted(event.calendarItemExternalIdentifier))" ¬
                        of calendar id "\(quoted(event.calendar?.calendarIdentifier))"
                end try
            end tell
            """)
    }

    func sections(at now: Date) -> [ResultList.Section] {
        shown = [:]
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            let request = ResultList.Item(
                id: Self.allowID, title: "Allow Calendar Access",
                subtitle: "Mado lists today’s and tomorrow’s events here.", kind: "",
                symbol: Self.symbol, action: "Allow")
            return [ResultList.Section(title: Self.title, items: [request])]
        }
        let calendar = Calendar.current
        let sources = Agenda.span(around: now, calendar: calendar).map { span in
            store.events(
                matching: store.predicateForEvents(
                    withStart: span.start, end: span.end, calendars: nil))
        }
        let found = Dictionary((sources ?? []).map { (Self.id(of: $0), $0) }) { first, _ in first }
        let agenda = Agenda(events: found.values.map(Self.event(from:)))
        let days = agenda.days(at: now, calendar: calendar)
        guard days.contains(where: { !$0.events.isEmpty }) else {
            let notice = ResultList.Notice(
                title: "No events today or tomorrow", detail: "Events in Calendar show up here.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let next = agenda.next(at: now)
        let meeting = agenda.nextMeeting(at: now)
        var preferred = false
        return days.enumerated().map { index, day in
            let items = day.events.compactMap { event -> ResultList.Item? in
                guard let source = found[event.id] else { return nil }
                let id = "\(Self.prefix)\(index).\(event.id)"
                shown[id] = Shown(event: event, source: source)
                var row = Self.item(
                    id: id, for: event, detail: agenda.detail(of: event, at: now),
                    colour: source.calendar?.color, joins: event == meeting)
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
            return [(allow, LauncherView.Action.primaryKeys)]
        }
        guard let picked = shown[id] else { return [] }
        let open = CommandAction(id: "open", title: Self.openTitle) {
            try Self.show(picked.source)
        }
        guard let meeting = picked.event.meeting else {
            return [(open, LauncherView.Action.primaryKeys)]
        }
        let join = CommandAction(id: "join", title: Self.joinTitle) {
            NSWorkspace.shared.open(meeting.url)
        }
        return [(join, LauncherView.Action.primaryKeys), (open, LauncherView.Action.secondaryKeys)]
    }
}
