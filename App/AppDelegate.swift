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
    private var launcherClosed: ContinuousClock.Instant?
    private let launcherView = LauncherView()
    private var search: SearchRunner<[ResultList.Section]>?
    private let apps = AppIndex()
    private var usage = Usage()
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
        usage = loadUsage()
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
            try SystemCommands.all.forEach(manager.commands.register)
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

    private func loadUsage() -> Usage {
        do {
            return try Usage.load(from: modules)
        } catch {
            logger.error("Usage failed to load: \(error, privacy: .public)")
            return Usage()
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
                    LauncherResult.sections(
                        for: query, apps: apps, commands: modules?.commands.all ?? [],
                        usage: usage)
                }
            },
            deliver: { [launcherView] sections in
                launcherView.results.sections = sections
            })
    }

    private func run(_ item: ResultList.Item, action index: Int) {
        let actions = LauncherResult.actions(
            for: item.id, query: launcherView.field.stringValue, apps: apps,
            commands: modules?.commands.all ?? [])
        guard actions.indices.contains(index) else { return }
        launcher?.orderOut(nil)
        let action = actions[index]
        Task { [weak self, logger] in
            do {
                try await action.perform()
                if !Fallback.all.contains(where: { $0.item.id == item.id }) {
                    self?.recordUse(of: item.id)
                }
            } catch CocoaError.userCancelled {
                logger.debug("Result \(item.id, privacy: .public) was canceled")
            } catch {
                logger.error(
                    "Result \(item.id, privacy: .public) failed: \(error, privacy: .public)")
            }
        }
    }

    private func recordUse(of id: String) {
        usage.record(id, at: .now)
        do {
            try usage.save(to: modules)
        } catch {
            logger.error("Saving usage failed: \(error, privacy: .public)")
        }
    }

    func windowDidResignKey(_: Notification) {
        launcher?.orderOut(nil)
        launcherClosed = .now
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
        let screen = LauncherScreen.load(from: modules).screen ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let size = CGSize(width: Self.launcherWidth, height: Self.launcherHeight)
            panel.setFrame(ScreenGeometry.centeredFrame(of: size, in: visible), display: false)
        }
        let lifetime = QueryLifetime.load(from: modules).duration
        if let closed = launcherClosed, let lifetime, closed.duration(to: .now) > lifetime {
            launcherView.field.stringValue = ""
        }
        search?.run(launcherView.field.stringValue)
        panel.makeKeyAndOrderFront(nil)
        launcherView.field.selectText(nil)
        CATransaction.setCompletionBlock { [signposter] in
            signposter.endInterval("open launcher", opening)
        }
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
