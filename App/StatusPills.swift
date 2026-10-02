import AppCore
import AppKit
import GlassUI

@MainActor
enum StatusPills {
    static let unknown = "–"
    static let percent = FloatingPointFormatStyle<Double>.Percent()
        .precision(.fractionLength(0))
    private static let whole = FloatingPointFormatStyle<Double>().precision(.fractionLength(0))
    private static let gigabyte = 1_000_000_000.0
    private static let speed = speedFormatter(showingUnit: false)
    private static let speedUnit = speedFormatter(showingUnit: true)
    private static let charging = "battery.100percent.bolt"
    private static let batteries = [
        "battery.0percent", "battery.25percent", "battery.50percent", "battery.75percent",
        "battery.100percent",
    ]
    private static let uptimeStyle = Duration.UnitsFormatStyle(
        allowedUnits: [.days, .hours, .minutes], width: .narrow, maximumUnitCount: 1,
        fractionalPart: .hide(rounded: .down))
    static let activityMonitor = "com.apple.ActivityMonitor"
    private static let apps = [
        "cpu": activityMonitor,
        "mem": activityMonitor,
        "uptime": "com.apple.SystemProfiler",
        "thermal": activityMonitor,
    ]
    private static let panes: [String: SettingsPane] = [
        "battery": .battery,
        "airpods": .bluetooth,
        "disk": .storage,
        "net": .network,
        "vpn": .vpn,
        "wifi": .wifi,
    ]
    private static let hiddenByDefault: Set = ["wifi"]

    static func action(for pill: StatusBar.Pill) -> CommandAction {
        if let pane = panes[pill.id] { return pane.open }
        return open(apps[pill.id], title: pill.action)
    }

    static func open(_ bundleID: String?, title: String) -> CommandAction {
        CommandAction(id: "open", title: title) {
            guard let app = bundleID.flatMap(NSWorkspace.shared.urlForApplication)
            else { throw CocoaError(.fileNoSuchFile) }
            _ = try await NSWorkspace.shared.openApplication(
                at: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func pills(for stats: SystemStats) -> [StatusBar.Pill] {
        let info = ProcessInfo.processInfo
        let free = stats.diskFree.map { (Double($0) / gigabyte).formatted(whole) }
        return [
            .init(
                id: "cpu", name: "CPU", symbol: "cpu",
                value: stats.cpu?.formatted(percent) ?? unknown, action: "Open Activity Monitor"),
            .init(
                id: "mem", name: "Memory", symbol: "memorychip",
                value: stats.memory?.formatted(percent) ?? unknown,
                action: "Open Activity Monitor"),
            stats.battery.map(pill),
            stats.headphones.map(pill),
            .init(
                id: "disk", name: "Disk free", symbol: "internaldrive", value: free ?? unknown,
                action: "Open Storage Settings", unit: free == nil ? "" : "GB"),
            pill(forDownload: stats.download),
            .init(
                id: "uptime", name: "Uptime", symbol: "clock.arrow.circlepath",
                value: Duration.seconds(info.systemUptime).formatted(uptimeStyle),
                action: "Show System Report"),
            .init(
                id: "thermal", name: "Thermal state", symbol: "thermometer.medium",
                value: name(of: info.thermalState), action: "Open Activity Monitor"),
            stats.vpn.map(pill),
            stats.wifi.map(pill),
        ]
        .compactMap(\.self)
        .filter { !hiddenByDefault.contains($0.id) }
    }

    static func symbol(for battery: SystemStats.Battery) -> String {
        guard battery.power != .charging else { return charging }
        return batteries[Int((battery.level * Double(batteries.count - 1)).rounded())]
    }

    private static func pill(for battery: SystemStats.Battery) -> StatusBar.Pill {
        .init(
            id: "battery", name: battery.power == .charging ? "Battery, charging" : "Battery",
            symbol: symbol(for: battery), value: battery.level.formatted(percent),
            action: "Battery Settings")
    }

    private static func pill(for headphones: SystemStats.Headphones) -> StatusBar.Pill {
        .init(
            id: "airpods", name: headphones.name, symbol: "headphones",
            value: headphones.level.formatted(percent), action: "Open Bluetooth Settings")
    }

    private static func pill(for vpn: SystemStats.VPN) -> StatusBar.Pill {
        let connected = vpn == .connected
        return .init(
            id: "vpn", name: "VPN", symbol: connected ? "checkmark.shield" : "shield.slash",
            value: connected ? "On" : "Off", action: "Open VPN Settings")
    }

    private static func pill(for wifi: SystemStats.WiFi) -> StatusBar.Pill {
        let value =
            switch wifi {
            case .off: "Off"
            case .disconnected: "Not connected"
            case .connected(let network): network ?? "Connected"
            }
        return .init(
            id: "wifi", name: "Wi-Fi", symbol: wifi == .off ? "wifi.slash" : "wifi",
            value: value, action: "Wi-Fi Settings")
    }

    private static func pill(forDownload bytesPerSecond: Double?) -> StatusBar.Pill {
        let bytes = bytesPerSecond.map { Int64($0) }
        return .init(
            id: "net", name: "Download speed", symbol: "arrow.up.arrow.down",
            value: bytes.map(speed.string(fromByteCount:)) ?? unknown,
            action: "Open Network Settings",
            unit: bytes.map { "\(speedUnit.string(fromByteCount: $0))/s" } ?? "")
    }

    private static func speedFormatter(showingUnit: Bool) -> ByteCountFormatter {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.allowsNonnumericFormatting = false
        formatter.includesUnit = showingUnit
        formatter.includesCount = !showingUnit
        return formatter
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
