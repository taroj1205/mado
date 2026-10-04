import AppCore
import AppKit
import ClipboardKit
import GlassUI
import InputKit
import os
import SearchKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private static let launcherRadius: CGFloat = 20

    private let logger = Log.logger("App")
    let signposter: OSSignposter
    private let launch: OSSignpostIntervalState
    private(set) var statusItem: NSStatusItem?
    private(set) var modules: ModuleManager?
    private(set) var settings: SettingsWindowController?
    private(set) var snippets: Snippets?
    private(set) var launcher: GlassPanel?
    private var launcherClosed: ContinuousClock.Instant?
    private(set) var pasteTarget: PasteTarget?
    let launcherView = LauncherView()
    private var search: SearchRunner<[ResultList.Section]>?
    let apps = AppIndex()
    let files = FileIndex()
    let rates = ExchangeRateFeed()
    let systemFeed = SystemFeed()
    let widgets = Widgets()
    var launcherGallery: WidgetGalleryWindow?
    private(set) var usage = Usage()
    private(set) var history = CalculatorHistory()
    let clipboardHistory = ClipboardHistory()
    let textTools = TextTools()
    let emojiPicker = EmojiPicker()
    var enteredScope = Scope.calculator
    private lazy var registry = LauncherHotKeys.makeRegistry()
    private lazy var hotKeys = LauncherHotKeys(
        modules: modules, registry: registry
    ) { [weak self] in self?.toggleLauncher() }
    lazy var editor = ItemEditor(
        modules: modules, registry: registry,
        name: { [weak self] id in
            (self?.sources).flatMap { LauncherResult.result(for: id, in: $0)?.name }
        },
        isAvailable: { [weak self] id in
            self?.modules?.keysPaused != true
                && (!ClipboardModule.commandIDs.contains(id)
                    || self?.clipboardHistory.isRunning == true)
        })
    #if DEBUG
        private var toggleSignal: (any DispatchSourceSignal)?
    #endif

    init(signposter: OSSignposter, launch: OSSignpostIntervalState) {
        self.signposter = signposter
        self.launch = launch
    }

    func applicationDidFinishLaunching(_: Notification) {
        modules = makeModules()
        HyperGlyph.isShown = RemapSettings.load(from: modules).showsHyperGlyph
        usage = Usage.load(from: modules)
        history = CalculatorHistory.load(from: modules)
        NSApp.mainMenu = MainMenu.make(target: self, settings: #selector(showSettings))
        statusItem = makeStatusItem(settings: #selector(showSettings))
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
        connectClipboardHistory()
        connectEmoji()
        #if DEBUG
            toggleSignal = makeToggleSignal { [weak self] in self?.toggleLauncher() }
            if NoFocus.isEnabled, let launcher { NoFocus.forwardKeys(to: launcher) }
        #endif
        signposter.endInterval("launch", launch)
        if OpenOnLaunch.isEnabled(in: modules) { showLauncher() }
    }

    private func makeModules() -> ModuleManager? {
        do {
            let manager = try ModuleManager(store: .standard())
            LauncherHotKeys.pauseKeysIfOff(in: manager)
            let library = try Snippets.registered(in: manager)
            snippets = library
            let openHistory = CalculatorHistory.command { [weak self] in
                self?.openCalculatorHistory()
            }
            let newLink = Quicklink.createCommand { [weak self] in self?.createQuicklink() }
            try (SystemCommands.all + [openHistory, newLink]).forEach(manager.commands.register)
            for descriptor in SettingsPage.all.compactMap(\.module) {
                try manager.register(
                    descriptor.makeModule(
                        in: manager, hotKeys: registry,
                        clipboard: .init(
                            history: clipboardHistory, textTools: textTools, emoji: emojiPicker),
                        snippets: library
                    ) { [weak self] in $0 ? self?.toggleLauncher() : self?.showLauncher() })
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
            contentRect: NSRect(origin: .zero, size: launcherSize),
            shape: .rounded(Self.launcherRadius))
        launcherView.onQuery = { [weak self] query in self?.search?.run(query) }
        launcherView.onCancel = { [weak self] in self?.hideLauncher() }
        launcherView.onRun = { [weak self] item, action in self?.run(item, action: action) }
        connectActions()
        connectGlances()
        panel.onEvent = { [launcherView] in launcherView.handle($0) }
        panel.glass.contentView = launcherView
        panel.initialFirstResponder = launcherView.field
        panel.delegate = self
        return panel
    }

    private func makeSearch() -> SearchRunner<[ResultList.Section]> {
        SearchRunner(
            search: { [weak self] query in await self?.results(for: query) ?? [] },
            deliver: { [weak self] sections in self?.show(sections) })
    }

    func launcherActions(for item: ResultList.Item) -> [LauncherView.Action] {
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
        let opensView =
            CalculatorHistory.opens(item.id)
            || [
                Quicklink.createID, ClipboardHistory.commandID, TextTools.commandID,
                EmojiPicker.commandID,
            ].contains(item.id)
        if !opensView { hideLauncher() }
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
        let keepsOpen = [ClipboardHistory.commandID, TextTools.commandID, EmojiPicker.commandID]
            .contains(id)
        if launcher?.isVisible == true, !keepsOpen {
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
    func showLauncher() {
        guard let panel = launcher else { return }
        pasteTarget = .frontmost()
        let opening = signposter.beginInterval("open launcher")
        let screen = LauncherScreen.load(from: modules).screen ?? NSScreen.main
        launcherView.widgetLayout = widgetPlacement?.layout
        showGlances()
        if let visible = screen?.visibleFrame {
            panel.setFrame(launcherFrame(in: visible), display: false)
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
        let controller =
            settings
            ?? SettingsWindowController(
                modules: modules, hotKeys: hotKeys, rates: rates, items: editor,
                snippets: snippets)
        settings = controller
        controller.showWindow(nil)
    }
}
