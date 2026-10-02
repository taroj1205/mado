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
    private lazy var registry = makeHotKeyRegistry()
    private lazy var hotKeys = LauncherHotKeys(
        modules: modules, registry: registry
    ) { [weak self] in self?.toggleLauncher() }
    private lazy var editor = ItemEditor(modules: modules, registry: registry) { [weak self] id in
        guard let self else { return nil }
        return LauncherResult.result(for: id, in: sources)?.name
    }
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
        usage = Usage.load(from: modules)
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
        editor.onHotKey = { [weak self] in self?.runHotKey(of: $0) }
        editor.onSave = { [weak self] in self?.saved($0, resettingRanking: $1) }
        editor.start()
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
            try SystemCommands.all.forEach(manager.commands.register)
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
        launcherView.actions = { [weak self] in self?.launcherActions(for: $0) ?? [] }
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
                return signposter.withIntervalSignpost("search") {
                    LauncherResult.sections(
                        for: query, in: sources, usage: usage, items: editor.settings)
                }
            },
            deliver: { [launcherView] sections in
                launcherView.show(sections)
                (launcherView.context, launcherView.contextSymbol) = LauncherResult.context(
                    for: sections)
            })
    }

    private func menu(
        for item: ResultList.Item
    ) -> (run: [CommandAction], edit: [ItemSheet.Field]) {
        let run = LauncherResult.actions(
            for: item.id, query: launcherView.field.stringValue, in: sources)
        let editable = LauncherResult.result(for: item.id, in: sources) != nil
        return (run, editable ? [.favourite, .hotkey, .aliases] : [])
    }

    private func launcherActions(for item: ResultList.Item) -> [LauncherView.Action] {
        let (actions, edits) = menu(for: item)
        let keys = [LauncherView.Action.primaryKeys, LauncherView.Action.secondaryKeys]
        let favourite = editor.settings[item.id].favourite
        return actions.enumerated().map { index, action in
            LauncherView.Action(action.title, keys: keys.indices.contains(index) ? keys[index] : [])
        } + edits.map { LauncherView.Action($0.title(favourite: favourite)) }
    }

    private func run(_ item: ResultList.Item, action index: Int) {
        let (actions, edits) = menu(for: item)
        if actions.indices.contains(index) {
            hideLauncher()
            perform(actions[index], for: item.id, recordingUse: !edits.isEmpty)
        } else if edits.indices.contains(index - actions.count), let launcher {
            let ranking = usage.summary(of: item.id, at: .now)
            editor.open(edits[index - actions.count], for: item, ranking: ranking, in: launcher)
        }
    }

    private func runHotKey(of id: String) {
        guard let action = LauncherResult.result(for: id, in: sources)?.actions.first else {
            logger.error("Hotkey item \(id, privacy: .private) is gone")
            return
        }
        if launcher?.isVisible == true {
            hideLauncher()
        }
        perform(action, for: id, recordingUse: true)
    }

    private func perform(_ action: CommandAction, for id: String, recordingUse: Bool) {
        Task { [weak self, logger] in
            do {
                try await action.perform()
                if recordingUse {
                    self?.recordUse(of: id)
                }
            } catch CocoaError.userCancelled {
                logger.debug("Result \(id, privacy: .private) was canceled")
            } catch {
                logger.error("Result \(id, privacy: .private) failed: \(error, privacy: .private)")
            }
        }
    }

    private func saved(_ id: String, resettingRanking: Bool) {
        if resettingRanking {
            usage.forget(id)
            usage.save(to: modules)
        }
        searchAgain()
    }

    private func recordUse(of id: String) {
        usage.record(id, at: .now)
        usage.save(to: modules)
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
        editor.close()
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
