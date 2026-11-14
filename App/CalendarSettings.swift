import AppCore
import AppKit
import EventKit

@MainActor
final class CalendarSettings {
    struct Stored: StoredValue, Equatable {
        static let key = "calendars"

        var hidden: Set<String> = []
    }

    private struct Entry: Equatable {
        let id: String
        let title: String
        let source: String
    }

    private struct Snapshot: Equatable {
        let hasAccess: Bool
        let entries: [Entry]
    }

    static let changed = Notification.Name("CalendarSettings.changed")

    private let modules: ModuleManager?
    private lazy var store = EKEventStore()
    var onChange: (() -> Void)?

    var section: SettingsSection {
        let calendars = current()
        let shown = snapshot(of: calendars)
        var built =
            if shown.hasAccess {
                SettingsSection("Calendars", calendars.map(row))
            } else {
                SettingsSection(
                    "Calendars", note: "Allow calendar access to pick which calendars show.", [])
            }
        built.refresh = { [weak self] in self?.reload(ifChangedFrom: shown) }
        return built
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    static func apply(from modules: ModuleManager?) {
        CalendarAgenda.hiddenCalendars = Stored.load(from: modules).hidden
    }

    private func snapshot(of calendars: [EKCalendar]) -> Snapshot {
        let entries = calendars.map { calendar in
            Entry(
                id: calendar.calendarIdentifier, title: calendar.title,
                source: calendar.source?.title ?? "")
        }
        return Snapshot(hasAccess: CalendarAgenda.hasAccess, entries: entries)
    }

    private func current() -> [EKCalendar] {
        guard CalendarAgenda.hasAccess else { return [] }
        let name = { (calendar: EKCalendar) in [calendar.source?.title ?? "", calendar.title] }
        let before = { (first: String, second: String) in
            first.localizedStandardCompare(second) == .orderedAscending
        }
        return store.calendars(for: .event).sorted { first, second in
            name(first).lexicographicallyPrecedes(name(second), by: before)
        }
    }

    private func reload(ifChangedFrom shown: Snapshot) {
        if snapshot(of: current()) != shown {
            onChange?()
        }
    }

    private func row(for calendar: EKCalendar) -> SettingsSection.Row {
        let id = calendar.calendarIdentifier
        let toggle = SettingsSwitch(
            read: { [modules] in !Stored.load(from: modules).hidden.contains(id) },
            write: { [modules] isShown in
                var stored = Stored.load(from: modules)
                if isShown {
                    stored.hidden.remove(id)
                } else {
                    stored.hidden.insert(id)
                }
                stored.save(to: modules)
                Self.apply(from: modules)
                NotificationCenter.default.post(name: Self.changed, object: nil)
            })
        toggle.isEnabled = modules != nil
        let icon = NSImageView(
            image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
                ?? NSImage())
        icon.contentTintColor = calendar.color
        let source = calendar.source?.title ?? ""
        var row = SettingsSection.Row(
            calendar.title, toggle, icon: icon, detail: source.isEmpty ? nil : { source })
        row.key = id
        row.isSearchable = false
        return row
    }
}
