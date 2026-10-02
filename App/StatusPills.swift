import AppCore
import AppKit
import GlassUI

@MainActor
enum StatusPills {
    private static let uptimeStyle = Duration.UnitsFormatStyle(
        allowedUnits: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 1,
        fractionalPart: .hide(rounded: .down))
    private static let apps = [
        "uptime": "com.apple.SystemProfiler",
        "thermal": "com.apple.ActivityMonitor",
    ]

    static func current() -> [StatusBar.Pill] {
        let info = ProcessInfo.processInfo
        return [
            .init(
                id: "uptime", name: "Uptime", symbol: "clock.arrow.circlepath",
                value: Duration.seconds(info.systemUptime).formatted(uptimeStyle),
                action: "Show System Report"),
            .init(
                id: "thermal", name: "Thermal state", symbol: "thermometer.medium",
                value: name(of: info.thermalState), action: "Open Activity Monitor"),
        ]
    }

    static func action(for pill: StatusBar.Pill) -> CommandAction {
        CommandAction(id: "open", title: pill.action) {
            guard let app = apps[pill.id].flatMap(NSWorkspace.shared.urlForApplication)
            else { throw CocoaError(.fileNoSuchFile) }
            _ = try await NSWorkspace.shared.openApplication(
                at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private static func name(of state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}
