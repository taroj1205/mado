import AppCore
import AppKit
import os
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let logger = Log.logger("App")
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private var statusItem: NSStatusItem?
    private var launchAtLoginItem: NSMenuItem?

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        statusItem = makeStatusItem()
        signposter.endInterval("launch", launch)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        return true
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.behavior = .removalAllowed
        item.isVisible = true
        item.button?.image = NSImage(
            systemSymbolName: "macwindow", accessibilityDescription: "Mado")

        let menu = NSMenu()
        menu.addItem(withTitle: "Open Mado", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: nil, keyEquivalent: ",")
        let launchAtLogin = menu.addItem(
            withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        launchAtLogin.target = self
        launchAtLoginItem = launchAtLogin
        menu.addItem(.separator())
        let hide = menu.addItem(
            withTitle: "Hide Menu Bar Icon", action: #selector(hideStatusItem), keyEquivalent: "")
        hide.target = self
        hide.toolTip = "Open Mado again to show the icon."
        menu.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        menu.delegate = self
        item.menu = menu
        return item
    }

    func menuNeedsUpdate(_: NSMenu) {
        launchAtLoginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc
    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()

            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()

            default:
                try service.register()
            }
        } catch {
            logger.error("Launch at login failed: \(error, privacy: .public)")
            NSApp.activate()
            NSApp.presentError(error)
        }
    }

    @objc
    private func hideStatusItem() {
        statusItem?.isVisible = false
    }
}
