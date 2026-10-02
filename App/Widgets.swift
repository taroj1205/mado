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

    private static var clock: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clockApp)
    }

    private var stats: SystemStats?
    private var ticking: Task<Void, Never>?

    static func action(for widget: WidgetGrid.Widget) -> CommandAction {
        if widget.id == system {
            return StatusPills.open(StatusPills.activityMonitor, title: widget.action)
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
            cpu == nil
                ? .init(
                    id: system, content: .loading(title: "System"),
                    action: "Open Activity Monitor", spoken: "System: loading")
                : .init(
                    id: system, meters: [meter("CPU", cpu), meter("RAM", memory)],
                    action: "Open Activity Monitor",
                    spoken: "System: CPU \(percent(cpu)), memory \(percent(memory))"),
        ]
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
