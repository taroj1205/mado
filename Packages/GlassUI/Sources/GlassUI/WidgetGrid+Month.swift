public import AppCore
public import AppKit

extension WidgetGrid {
    public enum Page: Sendable, Equatable {
        case previous
        case next
        case today
        case month
        case day(Date)
    }

    public struct Month: Sendable, Equatable {
        public let today: Date
        public let shift: Int
        public let events: [Agenda.Event]
        public let colours: [String: NSColor]
        public let opensDays: Bool
        public let searchesDays: Bool
        public let day: Date?

        public init(
            today: Date, shift: Int = 0, events: [Agenda.Event] = [],
            colours: [String: NSColor] = [:], opensDays: Bool = true, searchesDays: Bool = false,
            day: Date? = nil
        ) {
            self.today = today
            self.shift = shift
            self.events = events
            self.colours = colours
            self.opensDays = opensDays
            self.searchesDays = searchesDays
            self.day = day
        }

        func grid(in calendar: Calendar) -> AgendaMonth? {
            guard let shown = calendar.date(byAdding: .month, value: shift, to: today) else {
                return nil
            }
            return Agenda(events: events).month(showing: shown, at: today, calendar: calendar)
        }
    }
}
