import AppCore
import AppKit
import GlassUI

@MainActor
struct SettingsPane {
    static let all = [
        Self("Wi-Fi", "com.apple.wifi-settings-extension"),
        Self("Bluetooth", "com.apple.BluetoothSettings"),
        Self("Network", "com.apple.Network-Settings.extension"),
        Self("VPN", "com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension"),
        Self("Battery", "com.apple.Battery-Settings.extension", aliases: "Energy Saver"),
        Self("About", "com.apple.SystemProfiler.AboutExtension"),
        Self("Software Update", "com.apple.Software-Update-Settings.extension"),
        Self("Storage", "com.apple.settings.Storage"),
        Self(
            "AirDrop & Continuity", "com.apple.AirDrop-Handoff-Settings.extension",
            aliases: "AirDrop & Handoff"),
        Self("Login Items", "com.apple.LoginItems-Settings.extension"),
        Self("Language & Region", "com.apple.Localization-Settings.extension"),
        Self("Date & Time", "com.apple.Date-Time-Settings.extension"),
        Self("Sharing", "com.apple.Sharing-Settings.extension"),
        Self("Time Machine", "com.apple.Time-Machine-Settings.extension"),
        Self("Transfer or Reset", "com.apple.Transfer-Reset-Settings.extension"),
        Self("Startup Disk", "com.apple.Startup-Disk-Settings.extension"),
        Self("Accessibility", "com.apple.Accessibility-Settings.extension"),
        Self("Appearance", "com.apple.Appearance-Settings.extension"),
        Self("Menu Bar", "com.apple.ControlCenter-Settings.extension", aliases: "Control Center"),
        Self("Siri", "com.apple.Siri-Settings.extension", aliases: "Apple Intelligence & Siri"),
        Self("Spotlight", "com.apple.Spotlight-Settings.extension"),
        Self("Privacy & Security", "com.apple.settings.PrivacySecurity.extension"),
        Self("Desktop & Dock", "com.apple.Desktop-Settings.extension"),
        Self("Displays", "com.apple.Displays-Settings.extension"),
        Self("Wallpaper", "com.apple.Wallpaper-Settings.extension"),
        Self("Notifications", "com.apple.Notifications-Settings.extension"),
        Self("Sound", "com.apple.Sound-Settings.extension"),
        Self("Focus", "com.apple.Focus-Settings.extension"),
        Self("Screen Time", "com.apple.Screen-Time-Settings.extension"),
        Self("Lock Screen", "com.apple.Lock-Screen-Settings.extension"),
        Self(
            "Touch ID & Password", "com.apple.Touch-ID-Settings.extension",
            aliases: "Login Password"),
        Self("Users & Groups", "com.apple.Users-Groups-Settings.extension"),
        Self("Internet Accounts", "com.apple.Internet-Accounts-Settings.extension"),
        Self("Game Center", "com.apple.Game-Center-Settings.extension"),
        Self("Wallet & Apple Pay", "com.apple.WalletSettingsExtension"),
        Self("Keyboard", "com.apple.Keyboard-Settings.extension"),
        Self("Mouse", "com.apple.Mouse-Settings.extension"),
        Self("Trackpad", "com.apple.Trackpad-Settings.extension"),
        Self("Printers & Scanners", "com.apple.Print-Scan-Settings.extension"),
    ]

    private static let icon = NSWorkspace.shared.urlForApplication(
        withBundleIdentifier: "com.apple.systempreferences"
    )
    .map { NSWorkspace.shared.icon(forFile: $0.path) }

    let name: String
    let id: String
    let keys: [String]

    var item: ResultList.Item {
        ResultList.Item(
            id: id, title: name, subtitle: "", kind: "System Settings", symbol: "gearshape",
            icon: Self.icon)
    }

    var open: CommandAction {
        CommandAction(id: "open", title: "Open Settings") { [id] in
            guard let url = URL(string: id) else { return }
            _ = try await NSWorkspace.shared.open(
                url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private init(_ name: String, _ bundleID: String, aliases: String...) {
        self.name = name
        id = "x-apple.systempreferences:\(bundleID)"
        keys = [name] + aliases
    }
}
