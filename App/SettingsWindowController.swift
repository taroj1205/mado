import AppCore
import AppKit
import GlassUI
import SearchKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private final class Sidebar: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
        private static let rowHeight: CGFloat = 28
        private static let rowGap: CGFloat = 2
        private static let iconWidth: CGFloat = 18
        private static let iconGap: CGFloat = 9
        private static let topInset: CGFloat = 43

        private let tabs: NSTabViewController
        private let table = NSTableView()

        init(tabs: NSTabViewController) {
            self.tabs = tabs
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            nil
        }

        private static func tint(selected: Bool) -> NSColor {
            selected ? .controlAccentColor : .secondaryLabelColor
        }

        override func loadView() {
            table.style = .sourceList
            table.headerView = nil
            table.rowSizeStyle = .custom
            table.rowHeight = Self.rowHeight
            table.intercellSpacing = NSSize(width: 0, height: Self.rowGap)
            table.allowsEmptySelection = false
            table.addTableColumn(NSTableColumn())
            table.dataSource = self
            table.delegate = self
            let scroll = NSScrollView()
            scroll.documentView = table
            scroll.drawsBackground = false
            scroll.automaticallyAdjustsContentInsets = false
            scroll.contentInsets = NSEdgeInsets(top: Self.topInset, left: 0, bottom: 0, right: 0)
            let fill = NSBox()
            fill.boxType = .custom
            fill.titlePosition = .noTitle
            fill.borderWidth = 0
            fill.contentViewMargins = .zero
            fill.fillColor = SettingsWindowController.tint
            fill.contentView = scroll
            view = fill
            table.selectRowIndexes([0], byExtendingSelection: false)
        }

        func numberOfRows(in _: NSTableView) -> Int {
            SettingsPage.all.count
        }

        func tableView(_: NSTableView, rowViewForRow _: Int) -> NSTableRowView? {
            SettingsSidebarRow()
        }

        func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
            let page = SettingsPage.all[row]
            let image = NSImageView()
            image.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)
            image.contentTintColor = Self.tint(selected: row == table.selectedRow)
            image.widthAnchor.constraint(equalToConstant: Self.iconWidth).isActive = true
            let label = NSTextField(labelWithString: page.title)
            let stack = NSStackView(views: [image, label])
            stack.spacing = Self.iconGap
            stack.translatesAutoresizingMaskIntoConstraints = false
            let cell = NSTableCellView()
            unsafe cell.imageView = image
            cell.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }

        func tableView(_: NSTableView, typeSelectStringFor _: NSTableColumn?, row: Int) -> String? {
            SettingsPage.all[row].title
        }

        func tableViewSelectionDidChange(_: Notification) {
            tabs.selectedTabViewItemIndex = table.selectedRow
            table.enumerateAvailableRowViews { rowView, row in
                let cell = rowView.view(atColumn: 0) as? NSTableCellView
                unsafe cell?.imageView?.contentTintColor = Self.tint(
                    selected: row == table.selectedRow)
            }
        }
    }

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

    private let tabs: NSTabViewController

    init(
        modules: ModuleManager?, hotKeys: LauncherHotKeys, rates: ExchangeRateFeed,
        items: ItemEditor, snippets: Snippets?, addWidgets: @escaping @MainActor () -> Void
    ) {
        let recorder = HotKeyPopover(items: items)
        let ignoredApps = AppListSettings.ignoredApps(modules: modules)
        let withoutExpansion = AppListSettings.withoutExpansion(modules: modules)
        let inputKeys = InputSourceKeys(modules: modules, recorder: recorder)
        let inputDefaults = AppInputDefaults(modules: modules)
        let remaps = RemapsSettings(modules: modules, recorder: recorder)
        let enterGuard = EnterGuardPage(modules: modules)
        let context = SettingsPage.Context(
            modules: modules, hotKeys: hotKeys, rates: rates, recorder: recorder,
            apps: AppHotKeys(items: items, recorder: recorder),
            radial: RadialMenuSettings(modules: modules),
            clipboardHistory: ClipboardHistorySettings(modules: modules), ignoredApps: ignoredApps,
            withoutExpansion: withoutExpansion, inputKeys: inputKeys,
            inputDefaults: inputDefaults, remaps: remaps, enterGuard: enterGuard,
            addWidgets: addWidgets)
        let pages = Self.pages(context)
        let sidebar = NSSplitViewItem(sidebarWithViewController: Sidebar(tabs: pages))
        sidebar.canCollapse = false
        sidebar.minimumThickness = Self.sidebarWidth
        sidebar.maximumThickness = Self.sidebarWidth
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        split.addSplitViewItem(NSSplitViewItem(viewController: pages))

        let glass = GlassView(shape: .rounded(Self.cornerRadius), tint: Self.tint)
        glass.frame = split.splitView.bounds
        glass.autoresizingMask = [.width, .height]
        split.splitView.addSubview(glass, positioned: .below, relativeTo: nil)

        let window = Self.window(showing: split)
        tabs = pages
        super.init(window: window)
        window.delegate = self
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

    private static func window(showing split: NSSplitViewController) -> NSWindow {
        let window = NSWindow(contentViewController: split)
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
    }

    func windowDidBecomeKey(_: Notification) {
        refresh()
    }

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
