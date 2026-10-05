import AppCore
import AppKit
import GlassUI
import SearchKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private static let width: CGFloat = 820
    private static let height: CGFloat = 608
    private static let sidebarWidth: CGFloat = 208
    private static let cornerRadius: CGFloat = 26
    private static let tintGray: CGFloat = 0.094
    private static let tintBlue: CGFloat = 0.118
    private static let tintAlpha: CGFloat = 0.62
    static let tint = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: tintGray, green: tintGray, blue: tintBlue, alpha: tintAlpha)
            : .clear
    }

    let tabs: NSTabViewController
    let sidebar: SettingsSidebar
    let finder: SettingsFinder
    var home: Home?
    weak var spotlit: SettingsPageController?

    init(
        modules: ModuleManager?, hotKeys: LauncherHotKeys, rates: ExchangeRateFeed,
        items: ItemEditor, snippets: Snippets?, statusItem: NSStatusItem?,
        addWidgets: @escaping @MainActor () -> Void
    ) {
        let recorder = HotKeyPopover(items: items)
        let ignoredApps = AppListSettings.ignoredApps(modules: modules)
        let withoutExpansion = AppListSettings.withoutExpansion(modules: modules)
        let inputKeys = InputSourceKeys(modules: modules, recorder: recorder)
        let inputDefaults = AppInputDefaults(modules: modules)
        let remaps = RemapsSettings(modules: modules, recorder: recorder)
        let enterGuard = EnterGuardPage(modules: modules)
        let speechModels = SpeechModelSettings(modules: modules)
        let context = SettingsPage.Context(
            modules: modules, hotKeys: hotKeys, rates: rates, recorder: recorder,
            apps: AppHotKeys(items: items, recorder: recorder),
            radial: RadialMenuSettings(modules: modules),
            clipboardHistory: ClipboardHistorySettings(modules: modules), ignoredApps: ignoredApps,
            withoutExpansion: withoutExpansion, inputKeys: inputKeys,
            inputDefaults: inputDefaults, remaps: remaps, enterGuard: enterGuard,
            addWidgets: addWidgets, speechModels: speechModels,
            colourKeys: ColourPickerKeysPage(modules: modules), statusItem: statusItem)
        let pages = Self.pages(context)
        tabs = pages
        finder = SettingsFinder(context: context) {
            pages.tabViewItems.compactMap { ($0.viewController as? SettingsPageController)?.shown }
        }
        sidebar = SettingsSidebar(finder: finder)
        let window = Self.window(showing: Self.split(sidebar, pages))
        super.init(window: window)
        sidebar.delegate = self
        endSearchOnTabPicks()
        window.delegate = self
        window.onEscape = { [weak self] in self?.endSearchIfActive() ?? false }
        ignoredApps.onChange = { [weak self] in self?.reload() }
        withoutExpansion.onChange = { [weak self] in
            snippets?.reload()
            self?.reload()
        }
        inputKeys.onChange = { [weak self] in self?.reload() }
        inputDefaults.onChange = { [weak self] in self?.reload() }
        remaps.onChange = { [weak self] in self?.reload() }
        enterGuard.onChange = { [weak self] in self?.reload() }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func split(
        _ sidebar: SettingsSidebar, _ pages: NSTabViewController
    ) -> NSSplitViewController {
        let item = NSSplitViewItem(sidebarWithViewController: sidebar)
        item.canCollapse = false
        item.minimumThickness = sidebarWidth
        item.maximumThickness = sidebarWidth
        let split = NSSplitViewController()
        split.addSplitViewItem(item)
        split.addSplitViewItem(NSSplitViewItem(viewController: pages))
        let glass = GlassView(shape: .rounded(cornerRadius), tint: tint)
        glass.frame = split.splitView.bounds
        glass.autoresizingMask = [.width, .height]
        split.splitView.addSubview(glass, positioned: .below, relativeTo: nil)
        return split
    }

    private static func window(showing split: NSSplitViewController) -> SettingsWindow {
        let window = SettingsWindow(contentViewController: split)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Settings"
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: width, height: height))
        window.center()
        return window
    }

    private static func pages(_ context: SettingsPage.Context) -> NSTabViewController {
        let pages = NSTabViewController()
        pages.tabStyle = .unspecified
        for page in SettingsPage.all {
            pages.addTabViewItem(
                NSTabViewItem(
                    viewController: SettingsPageController(page: page, context: context)))
        }
        return pages
    }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        NSRunningApplication.current.activate(
            from: NSWorkspace.shared.frontmostApplication ?? .current, options: [])
        super.showWindow(sender)
    }

    func open(_ place: SettingsSearch.Place, entry: String?) {
        showWindow(nil)
        sidebar.go(to: .init(place: place, entry: entry, choice: false))
    }

    func refresh() {
        (tabs.tabViewItems[tabs.selectedTabViewItemIndex].viewController
            as? SettingsPageController)?.refresh()
    }

    func reload() {
        for item in tabs.tabViewItems {
            if let page = item.viewController as? SettingsPageController, page.isViewLoaded {
                page.reload()
            }
        }
        sidebar.reindex()
    }

    func windowDidBecomeKey(_: Notification) {
        refresh()
    }

    func windowWillClose(_: Notification) {
        sidebarEndedSearch()
        NSApp.setActivationPolicy(.accessory)
    }
}
