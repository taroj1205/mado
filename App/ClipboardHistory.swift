import AppCore
import AppKit
import Carbon.HIToolbox
import ClipboardKit
import GlassUI
import os
import SearchKit

@MainActor
final class ClipboardHistory: NSObject {
    private enum Filter: Equatable {
        case kind(Clip.Kind)
        case source(String)
    }

    static let commandID = "clipboard.history"
    static let title = "Clipboard History"
    static let symbol = "clipboard"
    static let placeholder = "Type to filter entries…"
    private static let hotkey = Shortcut(
        keyCode: UInt32(kVK_ANSI_V), modifiers: [.command, .option])
    private static let entryPrefix = "clipboard.entry."
    private static let shown = 1_000
    private static let iconSize: CGFloat = 16
    private static let byte: CGFloat = 255
    private static let logger = Log.logger("ClipboardHistory")

    let filter = NSPopUpButton(frame: .zero, pullsDown: false)
    var onOpen: (() -> Void)?
    var onClose: (() -> Void)?
    var onFilter: (() -> Void)?
    private var store: ClipboardStore?
    private var filters: [Filter?] = []
    private var selected: Filter?
    private var entries: [String: ClipboardStore.Entry] = [:]
    private lazy var filterWidth = filter.widthAnchor.constraint(equalToConstant: 0)

    override init() {
        super.init()
        filter.target = self
        filter.action = #selector(filterChanged)
        filter.refusesFirstResponder = true
        filter.setAccessibilityLabel("Filter by type or app")
    }

    static func assignDefaultHotKey(in editor: ItemEditor, modules: ModuleManager?) {
        var settings = ClipboardSettings.load(from: modules)
        guard !settings.assignedDefaultHotKey, modules?.isEnabled(ClipboardModule.id) == true
        else { return }
        editor.assignDefaults([(commandID, hotkey)])
        settings.assignedDefaultHotKey = true
        settings.save(to: modules)
    }

    private static func app(_ id: String) -> (name: String, icon: NSImage?) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else {
            return (id, nil)
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: iconSize, height: iconSize)
        return (AppIndex.name(of: url), icon)
    }

    private static func symbol(for kind: Clip.Kind) -> String {
        switch kind {
        case .text: "text.alignleft"
        case .richText: "textformat"
        case .image: "photo"
        case .file: "doc"
        case .url: "link"
        case .color: "circle.fill"
        }
    }

    private static func id(of entry: ClipboardStore.Entry) -> String {
        entryPrefix + String(entry.id)
    }

    private static func item(_ entry: ClipboardStore.Entry) -> ResultList.Item {
        let tint = entry.rgb.map { rgb in
            NSColor(
                srgbRed: CGFloat(rgb.red) / byte, green: CGFloat(rgb.green) / byte,
                blue: CGFloat(rgb.blue) / byte, alpha: 1)
        }
        return ResultList.Item(
            id: id(of: entry), title: entry.title, subtitle: "",
            kind: entry.kind.title, symbol: symbol(for: entry.kind), action: "", tint: tint)
    }

    func start(with store: ClipboardStore, context: ModuleContext) {
        self.store = store
        context.own(.other, "clipboard history") { [weak self] in self?.stop() }
        let open = CommandAction(id: "open", title: "Open \(Self.title)") { [weak self] in
            self?.reset()
            self?.onOpen?()
        }
        do {
            try context.register(
                Command(
                    id: Self.commandID, name: Self.title, icon: Self.symbol, actions: [open],
                    keywords: ["clipboard", "history", "copied", "paste"]))
        } catch {
            context.logger.error(
                "Clipboard history command failed: \(String(describing: error), privacy: .public)")
        }
    }

    func sections(for query: String) async -> [ResultList.Section] {
        guard let store else { return [] }
        let (kind, source): (Clip.Kind?, String?) =
            switch selected {
            case .kind(let kind): (kind, nil)
            case .source(let source): (nil, source)
            case nil: (nil, nil)
            }
        let found: [ClipboardStore.Entry]
        do {
            found = try await store.search(query, limit: Self.shown, kind: kind, source: source)
        } catch {
            Self.logger.error("Searching clipboard history failed: \(error, privacy: .public)")
            return []
        }
        guard !Task.isCancelled else { return [] }
        entries = Dictionary(uniqueKeysWithValues: found.map { (Self.id(of: $0), $0) })
        guard !found.isEmpty else {
            let empty = query.isEmpty && selected == nil
            let notice = ResultList.Notice(
                title: empty ? "No clipboard history yet" : "No matching entries",
                detail: empty ? "Things you copy show up here." : "Try another word or filter.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        let now = Date.now
        let calendar = Calendar.current
        return ClipboardStore.Entry.byDay(found, calendar: calendar).map { day, entries in
            ResultList.Section(
                title: RelativeDay.title(of: day, now: now, calendar: calendar),
                items: entries.map(Self.item))
        }
    }

    func preview(for item: ResultList.Item) -> LauncherView.Preview? {
        guard let entry = entries[item.id] else { return nil }
        let source = entry.source.map { Self.app($0).name } ?? "Unknown"
        return LauncherView.Preview(
            text: entry.preview, image: entry.image.map(NSImage.init(byReferencing:)),
            details: entry.details(source: source, now: .now, calendar: .current))
    }

    func actions(for id: String) -> [CommandAction] {
        guard let entry = entries[id] else { return [] }
        return [CommandAction(id: "copy", title: "Copy to Clipboard") { try entry.copy() }]
    }

    private func reset() {
        selected = nil
        rebuild(sources: [])
        Task { [weak self] in await self?.loadSources() }
    }

    private func stop() {
        store = nil
        entries = [:]
        onClose?()
    }

    private func loadSources() async {
        guard let store else { return }
        do {
            rebuild(sources: try await store.sources())
        } catch {
            Self.logger.error("Loading clipboard sources failed: \(error, privacy: .public)")
        }
    }

    private func rebuild(sources: [String]) {
        let menu = NSMenu()
        filters = []
        add("All Types", nil, to: menu)
        menu.addItem(.separator())
        for kind in Clip.Kind.allCases {
            add(kind.title, .kind(kind), to: menu)
        }
        if !sources.isEmpty {
            menu.addItem(.separator())
        }
        for source in sources {
            let app = Self.app(source)
            add(app.name, .source(source), to: menu, icon: app.icon)
        }
        filter.menu = menu
        filter.selectItem(withTag: filters.firstIndex(of: selected) ?? 0)
        fitFilter()
    }

    private func fitFilter() {
        let probe = NSPopUpButtonCell(textCell: "", pullsDown: false)
        probe.font = filter.font
        probe.addItem(withTitle: filter.titleOfSelectedItem ?? "")
        probe.lastItem?.image = filter.selectedItem?.image
        filterWidth.constant = ceil(probe.cellSize.width)
        filterWidth.isActive = true
    }

    private func add(_ title: String, _ choice: Filter?, to menu: NSMenu, icon: NSImage? = nil) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.tag = filters.count
        item.image = icon
        menu.addItem(item)
        filters.append(choice)
    }

    @objc
    private func filterChanged() {
        let tag = filter.selectedTag()
        guard filters.indices.contains(tag) else { return }
        selected = filters[tag]
        fitFilter()
        onFilter?()
    }
}
