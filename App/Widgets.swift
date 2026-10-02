import AppCore
import AppKit
import GlassUI

@MainActor
final class Widgets {
    static let moduleID = "widgets"
    private static let clockApp = "com.apple.clock"
    private static let minute: TimeInterval = 60
    private static let time = Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute()
    private static let spokenTime = Date.FormatStyle().hour().minute()
    private static let day = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
    private static let spokenDay = Date.FormatStyle().weekday(.wide).day().month(.wide)
    private static let system = "system"
    private static let battery = "battery"
    private static let batteryAction = "Battery Settings"
    private static let macName = "Mac"
    private static let owner = #/^\S+['’]s /#
    private static let timeLeft = Duration.TimeFormatStyle(pattern: .hourMinute)

    private static var clock: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clockApp)
    }

    private var stats: SystemStats?
    private var ticking: Task<Void, Never>?

    static func action(for widget: WidgetGrid.Widget) -> CommandAction {
        switch widget.id {
        case system: return StatusPills.open(StatusPills.activityMonitor, title: widget.action)
        case battery: return SettingsPane.battery.open
        default: break
        }
        guard let clock else { return SettingsPane.dateAndTime.open }
        return CommandAction(id: "open", title: widget.action) {
            _ = try await NSWorkspace.shared.openApplication(
                at: clock, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func current(at date: Date, stats: SystemStats?) -> [WidgetGrid.Widget] {
        let cpu = stats?.cpu
        let memory = stats?.memory
        return [
            .init(
                id: "clock", value: date.formatted(time), detail: date.formatted(day),
                action: clock == nil ? "Open Date & Time Settings" : "Open Clock",
                spoken: "Time: \(date.formatted(spokenTime)), \(date.formatted(spokenDay))"),
            stats == nil
                ? .init(
                    id: battery, content: .loading(title: "Battery"), action: batteryAction,
                    spoken: "Battery: loading")
                : stats.flatMap(batteries),
            cpu == nil
                ? .init(
                    id: system, content: .loading(title: "System"),
                    action: "Open Activity Monitor", spoken: "System: loading")
                : .init(
                    id: system, meters: [meter("CPU", cpu), meter("RAM", memory)],
                    action: "Open Activity Monitor",
                    spoken: "System: CPU \(percent(cpu)), memory \(percent(memory))"),
        ]
        .compactMap(\.self)
    }

    private static func batteries(in stats: SystemStats) -> WidgetGrid.Widget? {
        let mac = stats.battery
        let macStatus = mac.map { "\(percent($0.level)), \(status(of: $0).lowercased())" }
        guard let headphones = stats.headphones else {
            guard let mac, let macStatus else { return nil }
            return .init(
                id: battery, value: percent(mac.level), detail: status(of: mac),
                action: batteryAction, spoken: "Battery: \(macStatus)",
                symbol: StatusPills.symbol(for: mac))
        }
        let spoken = [
            macStatus.map { "\(macName) \($0)" },
            "\(headphones.name) \(percent(headphones.level))",
        ]
        return .init(
            id: battery,
            meters: [
                mac.map { meter(macName, $0.level) },
                meter(headphones.name.replacing(owner, with: ""), headphones.level),
            ]
            .compactMap(\.self),
            action: batteryAction,
            spoken: "Battery: \(spoken.compactMap(\.self).joined(separator: "; "))")
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

    private static func meter(_ name: String, _ level: Double?) -> WidgetGrid.Meter {
        .init(name: name, value: percent(level), level: level ?? 0)
    }

    private static func percent(_ level: Double?) -> String {
        level?.formatted(StatusPills.percent) ?? StatusPills.unknown
    }

    func show(in view: LauncherView) {
        stop()
        refresh(view)
        ticking = Task { [weak self, weak view] in
            while !Task.isCancelled {
                let now = Date.now.timeIntervalSinceReferenceDate
                let wait = Self.minute - now.truncatingRemainder(dividingBy: Self.minute)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let self, let view else { return }
                refresh(view)
            }
        }
    }

    func show(_ stats: SystemStats, in view: LauncherView) {
        self.stats = stats
        refresh(view)
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }

    private func refresh(_ view: LauncherView) {
        view.widgets = Self.current(at: .now, stats: stats)
    }
}
