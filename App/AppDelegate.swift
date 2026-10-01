import AppCore
import AppKit
import Carbon.HIToolbox
import GlassUI
import InputKit
import os
import SearchKit
import WindowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let launcherHotKey = Shortcut(keyCode: UInt32(kVK_Space), modifiers: .option)
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let launcherRadius: CGFloat = 28

    private let logger = Log.logger("App")
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private var statusItem: NSStatusItem?
    private var modules: ModuleManager?
    private var settings: SettingsWindowController?
    private var launcher: GlassPanel?
    private let launcherView = LauncherView()
    private var search: SearchRunner<[ResultList.Section]>?
    private let apps = AppIndex()
    private var hotKeys: HotKeyRegistry?
    #if DEBUG
        private var toggleSignal: (any DispatchSourceSignal)?
    #endif

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        modules = makeModules()
        NSApp.mainMenu = makeMainMenu()
        statusItem = makeStatusItem()
        launcher = makeLauncher()
        search = makeSearch()
        search?.run(launcherView.field.stringValue)
        apps.onChange = { [weak self] in
            guard let self else { return }
            search?.run(launcherView.field.stringValue)
        }
        apps.start()
        hotKeys = makeHotKeys()
        #if DEBUG
            toggleSignal = makeToggleSignal { [weak self] in self?.toggleLauncher() }
        #endif
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
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "MadoNoHotKey") { return nil }
        #endif
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
        launcherView.onQuery = { [weak self] query in self?.search?.run(query) }
        launcherView.onCancel = { [weak panel] in panel?.orderOut(nil) }
        launcherView.onRun = { [weak self] item, action in self?.run(item, action: action) }
        panel.glass.contentView = launcherView
        panel.initialFirstResponder = launcherView.field
        panel.delegate = self
        return panel
    }

    private func makeSearch() -> SearchRunner<[ResultList.Section]> {
        SearchRunner(
            search: { [weak self] query in
                guard let self else { return [] }
                return signposter.withIntervalSignpost("search") {
                    let commands = modules?.commands.commands(matching: query) ?? []
                    let typed = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let matches = typed ? apps.apps(matching: query) : []
                    return [
                        ResultList.Section(
                            title: typed ? "Results" : "Commands",
                            items: matches.map { app in
                                ResultList.Item(
                                    id: app.url.path, title: app.name, subtitle: app.folder,
                                    kind: "Application", symbol: "",
                                    icon: apps.icon(for: app))
                            }
                                + commands.map { command in
                                    ResultList.Item(
                                        id: command.id, title: command.name, subtitle: "",
                                        kind: "Command",
                                        symbol: command.icon)
                                })
                    ]
                }
            },
            deliver: { [launcherView] sections in
                launcherView.results.sections = sections
            })
    }

    private func run(_ item: ResultList.Item, action index: Int) {
        let actions = actions(for: item.id)
        guard actions.indices.contains(index) else { return }
        launcher?.orderOut(nil)
        let action = actions[index]
        Task { [logger] in
            do {
                try await action.perform()
            } catch {
                logger.error(
                    "Result \(item.id, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func actions(for id: String) -> [CommandAction] {
        guard let app = apps.apps.first(where: { $0.url.path == id }) else {
            return modules?.commands.command(id: id)?.actions ?? []
        }
        return [
            CommandAction(id: "open", title: "Open Application") {
                _ = try await NSWorkspace.shared.openApplication(
                    at: app.url, configuration: NSWorkspace.OpenConfiguration())
            }
        ]
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
        guard let panel = launcher else { return }
        let opening = signposter.beginInterval("open launcher")
        if let visible = (launcherScreen() ?? NSScreen.main)?.visibleFrame {
            let size = CGSize(width: Self.launcherWidth, height: Self.launcherHeight)
            panel.setFrame(ScreenGeometry.centeredFrame(of: size, in: visible), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        CATransaction.setCompletionBlock { [signposter] in
            signposter.endInterval("open launcher", opening)
        }
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
