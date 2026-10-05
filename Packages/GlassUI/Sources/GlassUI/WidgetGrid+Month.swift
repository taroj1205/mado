public import AppCore
public import AppKit

extension WidgetGrid {
    public enum Page: Sendable {
        case previous
        case next
        case today
    }

    public struct Month: Sendable, Equatable {
        public let today: Date
        public let shift: Int
        public let events: [Agenda.Event]
        public let colours: [String: NSColor]

        public init(
            today: Date, shift: Int = 0, events: [Agenda.Event] = [],
            colours: [String: NSColor] = [:]
        ) {
            self.today = today
            self.shift = shift
            self.events = events
            self.colours = colours
        }

        func grid(in calendar: Calendar) -> AgendaMonth? {
            guard let day = calendar.date(byAdding: .month, value: shift, to: today) else {
                return nil
            }
            return Agenda(events: events).month(showing: day, at: today, calendar: calendar)
        }
    }
}
