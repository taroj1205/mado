import AppCore
import Foundation
import GlassUI

extension Widgets {
    static func clockFacts(at date: Date) -> [WidgetGrid.Fact] {
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: date)
        return [
            .init(name: "Week", value: week.formatted()),
            calendar.ordinality(of: .day, in: .year, for: date).map { day in
                .init(name: "Day", value: day.formatted())
            },
            TimeZone.current.abbreviation(for: date).map { .init(name: "Zone", value: $0) },
        ]
        .compactMap(\.self)
    }

    static func batteryFacts(of battery: SystemStats.Battery) -> [WidgetGrid.Fact] {
        var facts: [WidgetGrid.Fact] = []
        if case .draining(let minutes) = battery.power {
            facts.append(.init(name: "Source", value: "Battery"))
            if let minutes {
                let left = Duration.seconds(Double(minutes) * minute)
                facts.append(.init(name: "Left", value: left.formatted(timeLeft)))
            }
        } else {
            facts.append(.init(name: "Source", value: "Adapter"))
        }
        return facts
    }

    static func systemFacts(of stats: SystemStats?) -> [WidgetGrid.Fact] {
        [
            .init(name: "Disk", value: StatusPills.diskFree(stats?.diskFree)),
            .init(name: "Net", value: StatusPills.downloadSpeed(stats?.download)),
            .init(name: "Uptime", value: StatusPills.uptime()),
            .init(name: "Thermal", value: StatusPills.thermal()),
        ]
    }
}
