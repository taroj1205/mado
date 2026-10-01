import AppCore
import AppKit

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private final class Sidebar: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
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

        override func loadView() {
            table.style = .sourceList
            table.headerView = nil
            table.allowsEmptySelection = false
            table.addTableColumn(NSTableColumn())
            table.dataSource = self
            table.delegate = self
            let scroll = NSScrollView()
            scroll.documentView = table
            scroll.drawsBackground = false
            view = scroll
            table.selectRowIndexes([0], byExtendingSelection: false)
        }

        func numberOfRows(in _: NSTableView) -> Int {
            SettingsPage.all.count
        }

        func tableView(_: NSTableView, viewFor _: NSTableColumn?, row: Int) -> NSView? {
            let page = SettingsPage.all[row]
            let image = NSImageView()
            image.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: nil)
            let label = NSTextField(labelWithString: page.title)
            let stack = NSStackView(views: [image, label])
            stack.translatesAutoresizingMaskIntoConstraints = false
            let cell = NSTableCellView()
            unsafe cell.imageView = image
            unsafe cell.textField = label
            cell.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                stack.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor),
                stack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }

        func tableViewSelectionDidChange(_: Notification) {
            tabs.selectedTabViewItemIndex = table.selectedRow
        }
    }

    private static let width: CGFloat = 820
    private static let height: CGFloat = 608
    private static let sidebarWidth: CGFloat = 208

    init(modules: ModuleManager?) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .unspecified
        for page in SettingsPage.all {
            tabs.addTabViewItem(
                NSTabViewItem(viewController: SettingsPageController(page: page, modules: modules))
            )
        }
        let sidebar = NSSplitViewItem(sidebarWithViewController: Sidebar(tabs: tabs))
        sidebar.canCollapse = false
        sidebar.minimumThickness = Self.sidebarWidth
        sidebar.maximumThickness = Self.sidebarWidth
        let split = NSSplitViewController()
        split.addSplitViewItem(sidebar)
        split.addSplitViewItem(NSSplitViewItem(viewController: tabs))

        let window = NSWindow(contentViewController: split)
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: Self.width, height: Self.height))
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func showWindow(_ sender: Any?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        super.showWindow(sender)
    }

    func windowWillClose(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
