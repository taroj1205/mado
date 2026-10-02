import AppCore
import AppKit
import ClipboardKit
import GlassUI
import InputKit
import os
import SearchKit
import WindowKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let launcherWidth: CGFloat = 760
    private static let launcherHeight: CGFloat = 548
    private static let launcherRadius: CGFloat = 20

    private let logger = Log.logger("App")
    private let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private(set) var statusItem: NSStatusItem?
    private(set) var modules: ModuleManager?
    private(set) var settings: SettingsWindowController?
    private var launcher: GlassPanel?
    private var launcherClosed: ContinuousClock.Instant?
    private(set) var pasteTarget: PasteTarget?
    let launcherView = LauncherView()
    private var search: SearchRunner<[ResultList.Section]>?
    let apps = AppIndex()
    let files = FileIndex()
    let rates = ExchangeRateFeed()
    let statusPills = StatusPills()
    let widgets = Widgets()
    private var usage = Usage()
    private var history = CalculatorHistory()
    private lazy var registry = LauncherHotKeys.makeRegistry()
    private lazy var hotKeys = LauncherHotKeys(
        modules: modules, registry: registry
    ) { [weak self] in self?.toggleLauncher() }
    lazy var editor = ItemEditor(modules: modules, registry: registry) { [weak self] id in
        (self?.sources).flatMap { LauncherResult.result(for: id, in: $0)?.name }
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
        rates.onChange = { [weak self] in self?.ratesChanged() }
        apps.start()
        files.start()
        rates.start(every: AnswerSettings.load(from: modules).refresh.seconds)
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

    private func makeModules() -> ModuleManager? {
        do {
            let manager = try ModuleManager(store: .standard())
            let openHistory = CalculatorHistory.command { [weak self] in
                self?.launcherView.enter(placeholder: CalculatorHistory.placeholder)
            }
            let newLink = Quicklink.createCommand { [weak self] in self?.createQuicklink() }
            try (SystemCommands.all + [openHistory, newLink]).forEach(manager.commands.register)
            for descriptor in SettingsPage.all.compactMap(\.module) {
                try manager.register(descriptor.makeModule(in: manager))
            }
            try manager.startEnabledModules()
            return manager
        } catch {
            logger.error("Modules failed to load: \(error, privacy: .public)")
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
        connectGlances()
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
                if launcherView.scoped { return history.sections(for: query) }
                return signposter.withIntervalSignpost("search") {
                    LauncherResult.sections(for: query, in: sources, usage: usage)
                }
            },
            deliver: { [launcherView] sections in
                launcherView.show(sections)
                (launcherView.context, launcherView.contextSymbol) =
                    launcherView.scoped
                    ? (CalculatorHistory.title, CalculatorHistory.symbol)
                    : LauncherResult.context(
                        for: sections, query: launcherView.field.stringValue)
            })
    }

    private func menu(for item: ResultList.Item) -> LauncherMenu {
        launcherView.scoped
            ? LauncherMenu(actions: history.actions(for: item.id))
            : LauncherMenu(
                for: item.id, query: launcherView.field.stringValue, in: sources, editor: editor,
                pastingInto: pasteTarget)
    }

    private func launcherActions(for item: ResultList.Item) -> [LauncherView.Action] {
        menu(for: item).actions(
            labelling: { editor.action(for: $0, on: item.id) },
            running: { [weak self] in self?.run($0, for: item, recordingUse: $1) })
    }

    private func run(_ item: ResultList.Item, action index: Int) {
        let menu = menu(for: item)
        switch menu.entry(at: index) {
        case let .run(action, _, _): run(action, for: item, recordingUse: menu.recordsUse)
        case .openWith, nil: break

        case .edit(let edit):
            guard let launcher else { return }
            let ranking = usage.summary(of: item.id, at: .now)
            editor.perform(edit, for: item, ranking: ranking, in: launcher)
        }
    }

    private func run(_ action: CommandAction, for item: ResultList.Item, recordingUse: Bool) {
        if !CalculatorHistory.opens(item.id), item.id != Quicklink.createID { hideLauncher() }
        history.remember(item, in: modules)
        perform(action, for: item.id, recordingUse: recordingUse)
    }

    private func createQuicklink() {
        if launcher?.isVisible != true { showLauncher() }
        if let launcher { editor.openQuicklink(Quicklink(name: "", link: ""), in: launcher) }
    }

    private func runHotKey(of id: String) {
        guard let action = LauncherResult.hotKeyAction(for: id, in: sources) else {
            logger.error("Hotkey item \(id, privacy: .private) is gone")
            return
        }
        if launcher?.isVisible == true {
            hideLauncher()
        }
        perform(action, for: id, recordingUse: true)
    }

    func perform(_ action: CommandAction, for id: String, recordingUse: Bool) {
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
        settings?.reload()
    }

    private func recordUse(of id: String) {
        usage.record(id, at: .now)
        usage.save(to: modules)
    }

    func searchAgain() {
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

    func hideLauncher() {
        editor.close()
        launcherView.leave()
        launcherView.endBrowsing()
        launcher?.orderOut(nil)
        hideGlances()
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
        pasteTarget = .frontmost()
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
        showGlances()
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
        let controller =
            settings
            ?? SettingsWindowController(
                modules: modules, hotKeys: hotKeys, rates: rates, items: editor)
        settings = controller
        controller.showWindow(nil)
    }
}
