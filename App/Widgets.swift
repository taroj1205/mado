import AppCore
import AppKit
import GlassUI

@MainActor
final class Widgets {
    private static let clockApp = "com.apple.clock"
    private static let minute: TimeInterval = 60
    private static let time = Date.FormatStyle().hour(.defaultDigits(amPM: .omitted)).minute()
    private static let spokenTime = Date.FormatStyle().hour().minute()
    private static let day = Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
    private static let spokenDay = Date.FormatStyle().weekday(.wide).day().month(.wide)

    private static var clock: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: clockApp)
    }

    private var ticking: Task<Void, Never>?

    static func action(for widget: WidgetGrid.Widget) -> CommandAction {
        guard let clock else { return SettingsPane.dateAndTime.open }
        return CommandAction(id: "open", title: widget.action) {
            _ = try await NSWorkspace.shared.openApplication(
                at: clock, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func current(at date: Date) -> [WidgetGrid.Widget] {
        [
            .init(
                id: "clock", value: date.formatted(time), detail: date.formatted(day),
                action: clock == nil ? "Open Date & Time Settings" : "Open Clock",
                spoken: "Time: \(date.formatted(spokenTime)), \(date.formatted(spokenDay))")
        ]
    }

    func show(in view: LauncherView) {
        stop()
        view.widgets = Self.current(at: .now)
        ticking = Task { [weak view] in
            while !Task.isCancelled {
                let now = Date.now.timeIntervalSinceReferenceDate
                let wait = Self.minute - now.truncatingRemainder(dividingBy: Self.minute)
                try? await Task.sleep(for: .seconds(wait))
                guard !Task.isCancelled, let view else { return }
                view.widgets = Self.current(at: .now)
            }
        }
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }
}
