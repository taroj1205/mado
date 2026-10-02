import AppCore
import AppKit
import GlassUI
import InputKit
import os
import SearchKit
import WindowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 476
    private static let launcherRadius: CGFloat = 20

    private let logger = Log.logger("App")
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private var statusItem: NSStatusItem?
    private var modules: ModuleManager?
    private(set) var settings: SettingsWindowController?
    private var launcher: GlassPanel?
    private var launcherClosed: ContinuousClock.Instant?
    private let launcherView = LauncherView()
    private var search: SearchRunner<[ResultList.Section]>?
    private let apps = AppIndex()
    private let files = FileIndex()
    private let rates = ExchangeRateFeed()
    private var usage = Usage()
    private var history = CalculatorHistory()
    private lazy var hotKeys = LauncherHotKeys(
        modules: modules, registry: makeHotKeyRegistry()
    ) { [weak self] in self?.toggleLauncher() }
    private var sources: LauncherResult.Sources {
        LauncherResult.Sources(
            apps: apps, files: files, commands: modules?.commands.all ?? [], rates: rates.rates)
    }
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
        history = CalculatorHistory.load(from: modules)
        NSApp.mainMenu = MainMenu.make(target: self, settings: #selector(showSettings))
        statusItem = StatusMenu.makeItem(
            target: self, open: #selector(showLauncher), settings: #selector(showSettings),
            hide: #selector(hideStatusItem))
        launcher = makeLauncher()
        search = makeSearch()
        searchAgain()
        apps.onChange = { [weak self] in self?.searchAgain() }
        files.onChange = { [weak self] in self?.searchAgain() }
        rates.onChange = { [weak self] in self?.searchAgain() }
        apps.start()
        files.start()
        rates.start()
        hotKeys.onChange = { [weak self] in self?.settings?.refresh() }
        hotKeys.start()
        #if DEBUG
            toggleSignal = makeToggleSignal { [weak self] in self?.toggleLauncher() }
            if NoFocus.isEnabled, let launcher { NoFocus.forwardKeys(to: launcher) }
        #endif
        signposter.endInterval("launch", launch)
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        statusItem?.isVisible = true
        return true
    }

    private func makeModules() -> ModuleManager? {
        do {
            let manager = try ModuleManager(store: .standard())
            let openHistory = CalculatorHistory.command { [weak self] in self?.openHistory() }
            try (SystemCommands.all + [openHistory]).forEach(manager.commands.register)
            for descriptor in SettingsPage.all.compactMap(\.module) {
                try manager.register(descriptor.makeModule())
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

    private func makeHotKeyRegistry() -> HotKeyRegistry? {
        #if DEBUG
            if UserDefaults.standard.bool(forKey: "MadoNoHotKey") { return nil }
        #endif
        do {
            return try HotKeyRegistry()
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
        launcherView.onCancel = { [weak self] in self?.hideLauncher() }
        launcherView.onRun = { [weak self] item, action in self?.run(item, action: action) }
        launcherView.actionTitles = { [weak self] in self?.actions(for: $0).map(\.title) ?? [] }
        panel.onEvent = { [launcherView] in launcherView.handle($0) }
        panel.glass.contentView = launcherView
        panel.initialFirstResponder = launcherView.field
        panel.delegate = self
        return panel
    }

    private func makeSearch() -> SearchRunner<[ResultList.Section]> {
        SearchRunner(
            search: { [weak self] query in
                guard let self else { return [] }
                if launcherView.scoped {
                    return history.sections(for: query, now: .now, calendar: .current)
                }
                return signposter.withIntervalSignpost("search") {
                    LauncherResult.sections(for: query, in: sources, usage: usage)
                }
            },
            deliver: { [launcherView] sections in
                launcherView.show(sections)
                (launcherView.context, launcherView.contextSymbol) =
                    launcherView.scoped
                    ? (CalculatorHistory.title, CalculatorHistory.symbol)
                    : LauncherResult.context(for: sections)
            })
    }

    private func actions(for item: ResultList.Item) -> [CommandAction] {
        if launcherView.scoped { return history.actions(for: item.id) }
        return LauncherResult.actions(
            for: item.id, query: launcherView.field.stringValue, in: sources)
    }

    private func run(_ item: ResultList.Item, action index: Int) {
        let actions = actions(for: item)
        guard actions.indices.contains(index) else { return }
        if !CalculatorHistory.opens(item.id) {
            hideLauncher()
        }
        let action = actions[index]
        Task { [weak self, logger] in
            do {
                try await action.perform()
                if LauncherResult.isRanked(item) {
                    self?.recordUse(of: item.id)
                }
                self?.history.remember(item, in: self?.modules)
            } catch CocoaError.userCancelled {
                logger.debug("Result \(item.id, privacy: .private) was canceled")
            } catch {
                logger.error(
                    "Result \(item.id, privacy: .private) failed: \(error, privacy: .private)")
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

    private func openHistory() {
        launcherView.enter(placeholder: CalculatorHistory.placeholder)
    }

    private func searchAgain() {
        search?.run(launcherView.field.stringValue)
    }

    func windowDidResignKey(_: Notification) {
        guard !launcherView.sharing else { return }
        #if DEBUG
            if KeepLauncherOpen.isEnabled { return }
        #endif
        hideLauncher()
    }

    #if DEBUG
        func applicationDidResignActive(_: Notification) {
            if !KeepLauncherOpen.isEnabled, !launcherView.sharing, launcher?.isVisible == true {
                hideLauncher()
            }
        }
    #endif

    private func hideLauncher() {
        launcherView.leave()
        launcherView.endBrowsing()
        launcher?.orderOut(nil)
        launcherClosed = .now
    }

    private func toggleLauncher() {
        if launcher?.isVisible == true {
            hideLauncher()
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
        #if DEBUG
            NoFocus.show(panel)
        #else
            panel.makeKeyAndOrderFront(nil)
        #endif
        launcherView.field.selectText(nil)
        CATransaction.setCompletionBlock { [signposter] in
            signposter.endInterval("open launcher", opening)
        }
    }

    @objc
    private func showSettings() {
        let controller = settings ?? SettingsWindowController(modules: modules, hotKeys: hotKeys)
        settings = controller
        controller.showWindow(nil)
    }

    @objc
    private func hideStatusItem() {
        statusItem?.isVisible = false
    }
}
