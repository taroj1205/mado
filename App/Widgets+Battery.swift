import AppCore
import Foundation
import GlassUI

extension Widgets {
    static let batteryAction = "Battery Settings"
    private static let macName = "Mac"
    private static let owner = #/^\S+['’]s /#
    private static let timeLeft = Duration.TimeFormatStyle(pattern: .hourMinute)

    static func batteries(in stats: SystemStats) -> WidgetGrid.Widget? {
        let mac = stats.battery
        let macStatus = mac.map { "\(percent($0.level)), \(status(of: $0).lowercased())" }
        guard let headphones = stats.headphones else {
            guard let mac, let macStatus else { return nil }
            return .init(
                id: battery, name: name(of: battery), value: percent(mac.level),
                detail: status(of: mac),
                action: batteryAction, spoken: "Battery: \(macStatus)",
                symbol: StatusPills.symbol(for: mac))
        }
        let spoken = [
            macStatus.map { "\(macName) \($0)" },
            "\(headphones.name) \(percent(headphones.level))",
        ]
        return .init(
            id: battery, name: name(of: battery), meters: batteryMeters(in: stats),
            action: batteryAction,
            spoken: "Battery: \(spoken.compactMap(\.self).joined(separator: "; "))")
    }

    static func batteryMeters(in stats: SystemStats) -> [WidgetGrid.Meter] {
        [
            stats.battery.map { meter(macName, $0.level) },
            stats.headphones.map { meter($0.name.replacing(owner, with: ""), $0.level) },
        ]
        .compactMap(\.self)
    }

    private static func status(of battery: SystemStats.Battery) -> String {
        switch battery.power {
        case .charging: "Charging"
        case .charged: "Charged"
        case .notCharging: "Not charging"

        case .draining(let minutes?):
            "\(Duration.seconds(Double(minutes) * minute).formatted(timeLeft)) left"

        case .draining(nil): "On battery"
        }
    }
}
