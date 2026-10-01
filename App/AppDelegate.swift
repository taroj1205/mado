import AppCore
import AppKit
import Carbon.HIToolbox
import GlassUI
import InputKit
import os
import WindowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate, NSWindowDelegate {
    private static let launcherHotKey = Shortcut(keyCode: UInt32(kVK_Space), modifiers: .option)
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let launcherRadius: CGFloat = 28
    private static let searchBarHalfHeight: CGFloat = 30
    private static let searchInset: CGFloat = 20

    private let logger = Log.logger("App")
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private var statusItem: NSStatusItem?
    private var modules: ModuleManager?
    private var settings: SettingsWindowController?
    private var launcher: GlassPanel?
    private var hotKeys: HotKeyRegistry?

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        modules = makeModules()
        NSApp.mainMenu = makeMainMenu()
        statusItem = makeStatusItem()
        hotKeys = makeHotKeys()
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
        let open = menu.addItem(
            withTitle: "Open Mado", action: #selector(showLauncher), keyEquivalent: "")
        open.target = self
        let settingsItem = menu.addItem(
            withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(.separator())
        let hide = menu.addItem(
            withTitle: "Hide Menu Bar Icon", action: #selector(hideStatusItem), keyEquivalent: "")
        hide.target = self
        hide.toolTip = "Open Mado again to show the icon."
        menu.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        item.menu = menu
        return item
    }

    private func makeMainMenu() -> NSMenu {
        let app = NSMenu()
        let settingsItem = app.addItem(
            withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        app.addItem(.separator())
        app.addItem(
            withTitle: "Hide Mado", action: #selector(NSApplication.hide), keyEquivalent: "h")
        app.addItem(
            withTitle: "Quit Mado", action: #selector(NSApplication.terminate), keyEquivalent: "q")
        let window = NSMenu(title: "Window")
        window.addItem(
            withTitle: "Close", action: #selector(NSWindow.performClose), keyEquivalent: "w")
        window.addItem(
            withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize),
            keyEquivalent: "m")
        NSApp.windowsMenu = window

        let menu = NSMenu()
        for submenu in [app, window] {
            menu.addItem(withTitle: submenu.title, action: nil, keyEquivalent: "").submenu = submenu
        }
        return menu
    }

    private func makeModules() -> ModuleManager? {
        do {
            let manager = try ModuleManager(store: .standard())
            for descriptor in SettingsPage.all.compactMap(\.module) {
                try manager.register(PlaceholderModule(descriptor: descriptor))
            }
            try manager.startEnabledModules()
            return manager
        } catch {
            logger.error("Modules failed to load: \(error, privacy: .public)")
            return nil
        }
    }

    private func makeHotKeys() -> HotKeyRegistry? {
        do {
            let registry = try HotKeyRegistry()
            try registry.register(Self.launcherHotKey) { [weak self] in
                self?.toggleLauncher()
            }
            return registry
        } catch {
            logger.error("Launcher hotkey failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private func makeLauncher() -> GlassPanel {
        let panel = GlassPanel(
            kind: .panel,
            contentRect: NSRect(x: 0, y: 0, width: Self.launcherWidth, height: Self.launcherHeight),
            shape: .rounded(Self.launcherRadius))
        let field = NSTextField()
        field.placeholderString = "Search"
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: Self.searchInset),
            field.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -Self.searchInset),
            field.centerYAnchor.constraint(
                equalTo: content.topAnchor, constant: Self.searchBarHalfHeight),
        ])
        panel.glass.contentView = content
        panel.initialFirstResponder = field
        panel.delegate = self
        return panel
    }

    func control(
        _: NSControl, textView _: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation) else { return false }
        launcher?.orderOut(nil)
        return true
    }

    func windowDidResignKey(_: Notification) {
        launcher?.orderOut(nil)
    }

    private func toggleLauncher() {
        if let panel = launcher, panel.isVisible {
            panel.orderOut(nil)
        } else {
            showLauncher()
        }
    }

    @objc
    private func showLauncher() {
        let panel = launcher ?? makeLauncher()
        launcher = panel
        if let visible = (launcherScreen() ?? NSScreen.main)?.visibleFrame {
            panel.setFrameOrigin(
                ScreenGeometry.upperThirdOrigin(of: panel.frame.size, in: visible))
        }
        panel.makeKeyAndOrderFront(nil)
    }

    private func launcherScreen() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        let mouseScreen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
        switch LauncherScreen.load(from: modules) {
        case .mouse:
            return mouseScreen

        case .activeWindow:
            return activeWindowScreen() ?? mouseScreen
        }
    }

    private func activeWindowScreen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
            let windows = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
            let window = windows.first(where: { info in
                info[kCGWindowOwnerPID as String] as? pid_t == pid
                    && info[kCGWindowLayer as String] as? Int == 0
            }),
            let dictionary = window[kCGWindowBounds as String] as? [String: Any],
            let bounds = CGRect(dictionaryRepresentation: dictionary as CFDictionary)
        else { return nil }
        let screens = NSScreen.screens
        return ScreenGeometry.screenIndex(showing: bounds, in: screens.map(\.frame))
            .map { screens[$0] }
    }

    @objc
    private func showSettings() {
        let controller = settings ?? SettingsWindowController(modules: modules)
        settings = controller
        controller.showWindow(nil)
    }

    @objc
    private func hideStatusItem() {
        statusItem?.isVisible = false
    }
}
