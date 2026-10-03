import AppCore
import AppKit
import GlassUI
import InputKit
import os
import SearchKit
import WindowKit

@MainActor
final class ItemEditor {
    enum Edit {
        case field(ItemSheet.Field)
        case createQuicklink
        case editQuicklink
    }

    private struct Host {
        let panel: GlassPanel
        let content: NSView?
        let focus: NSView?
    }

    private static let badLink = "Mado can’t open this link. Use a web address or a folder path."

    let sheet = ItemSheet()
    let quicklinkSheet = QuicklinkSheet()
    var onHotKey: ((String) -> Void)?
    var onSave: ((_ id: String, _ resetsRanking: Bool) -> Void)?

    private(set) var settings: ItemSettings
    private(set) var quicklinks: Quicklinks
    private let logger = Log.logger("App")
    private let modules: ModuleManager?
    private let registry: HotKeyRegistry?
    private let name: (String) -> String?
    private let isAvailable: (String) -> Bool
    private var registrations: [String: HotKeyRegistration] = [:]
    private var host: Host?

    init(
        modules: ModuleManager?, registry: HotKeyRegistry?, name: @escaping (String) -> String?,
        isAvailable: @escaping (String) -> Bool
    ) {
        settings = ItemSettings.load(from: modules)
        quicklinks = Quicklinks.load(from: modules)
        self.modules = modules
        self.registry = registry
        self.name = name
        self.isAvailable = isAvailable
        sheet.onRecording = { [weak self] in self?.suspendHotKeys($0) }
        sheet.onCancel = { [weak self] in self?.close() }
        quicklinkSheet.onRecording = { [weak self] in self?.suspendHotKeys($0) }
        quicklinkSheet.onCancel = { [weak self] in self?.close() }
        quicklinkSheet.applications = { Quicklink.applications(for: $0) }
        quicklinkSheet.websiteIcon = { await Quicklink.websiteIcon(for: $0) }
    }

    func start() {
        WindowLayouts.assignDefaultHotKeys(in: self, modules: modules)
        for (id, hotkey) in settings.hotkeys {
            register(hotkey, for: id)
        }
    }

    func refreshHotKey(for id: String) {
        if let registration = registrations.removeValue(forKey: id) {
            registry?.unregister(registration)
        }
        if let hotkey = settings[id].hotkey {
            register(hotkey, for: id)
        }
    }

    func edits(for id: String) -> [Edit] {
        if quicklinks[id] != nil { return [.field(.favourite), .editQuicklink] }
        let fields: [Edit] = [.field(.favourite), .field(.hotkey), .field(.aliases)]
        return id == Quicklink.createID ? fields : fields + [.createQuicklink]
    }

    func action(for edit: Edit, on id: String) -> LauncherView.Action {
        switch edit {
        case .field(let field): LauncherView.Action(field.title(favourite: settings[id].favourite))
        case .createQuicklink: LauncherView.Action(Quicklink.createTitle, keys: ["⌘", "⇧", "L"])
        case .editQuicklink: LauncherView.Action("Edit Quicklink")
        }
    }

    func perform(
        _ edit: Edit, for item: ResultList.Item, ranking: String?, in panel: GlassPanel
    ) {
        switch edit {
        case .field(let field):
            open(field, for: item, ranking: ranking, in: panel)

        case .createQuicklink:
            let link = item.file.map { Quicklink(name: item.title, link: $0.path) }
            openQuicklink(link ?? Quicklink(name: "", link: ""), in: panel)

        case .editQuicklink:
            if let link = quicklinks[item.id] {
                openQuicklink(link, in: panel)
            }
        }
    }

    func openQuicklink(_ link: Quicklink, in panel: GlassPanel) {
        present(quicklinkSheet, in: panel)
        let current = settings[link.id]
        quicklinkSheet.conflict = { [weak self] in self?.conflict(for: $0, besides: link.id) }
        quicklinkSheet.onSave = { [weak self] in self?.save($0, as: link) }
        quicklinkSheet.show(
            QuicklinkSheet.Values(
                name: link.name, link: link.link, app: link.app, icon: link.icon,
                alias: current.aliases.first ?? "", hotkey: current.hotkey),
            editing: quicklinks[link.id] != nil)
    }

    func close() {
        guard let host else { return }
        self.host = nil
        host.panel.glass.contentView = host.content
        host.panel.initialFirstResponder = host.focus
        host.panel.makeFirstResponder(host.focus)
        (host.focus as? NSTextField)?.selectText(nil)
    }

    private func open(
        _ field: ItemSheet.Field, for item: ResultList.Item, ranking: String?,
        in panel: GlassPanel
    ) {
        present(sheet, in: panel)
        let current = settings[item.id]
        sheet.conflict = { [weak self] in self?.conflict(for: $0, besides: item.id) }
        sheet.onSave = { [weak self] in self?.save($0, for: item.id) }
        sheet.show(
            item,
            values: ItemSheet.Values(
                aliases: current.aliases, hotkey: current.hotkey, favourite: current.favourite,
                quickPeek: current.quickPeek),
            ranking: ranking, opening: field,
            isApp: AppToggle.app(for: item.id) != nil)
    }

    private func present(_ view: NSView, in panel: GlassPanel) {
        close()
        host = Host(
            panel: panel, content: panel.glass.contentView, focus: panel.initialFirstResponder)
        panel.glass.contentView = view
    }

    func assign(_ hotkey: Shortcut?, to id: String) -> String? {
        if let problem = bind(hotkey, to: id) {
            return problem
        }
        settings[id].hotkey = hotkey
        settings.save(to: modules)
        onSave?(id, false)
        return nil
    }

    func setQuickPeek(_ quickPeek: Bool, for id: String) {
        settings[id].quickPeek = quickPeek
        settings.save(to: modules)
    }

    func assignDefaults(_ defaults: [(id: String, hotkey: Shortcut)]) {
        for (id, hotkey) in defaults
        where settings[id].hotkey == nil && conflict(for: hotkey, besides: id) == nil {
            settings[id].hotkey = hotkey
        }
        settings.save(to: modules)
    }

    func suspendHotKeys(_ suspended: Bool) {
        registry?.isSuspended = suspended
    }

    func conflict(for hotkey: Shortcut, besides id: String) -> String? {
        if LauncherHotKeys.Key.allCases.contains(where: { $0.shortcut == hotkey }) {
            return "Mado"
        }
        if let owner = settings.owner(of: hotkey), owner != id {
            return name(owner) ?? "Another item"
        }
        return switch SystemShortcutConflicts.conflict(for: hotkey) {
        case .spotlight: "Spotlight"
        case .finderSearch: "Finder search"
        case nil: nil
        }
    }

    private func save(_ values: ItemSheet.Values, for id: String) -> String? {
        if let problem = bind(values.hotkey, to: id) {
            return problem
        }
        settings[id] = ItemSettings.Item(
            aliases: values.aliases, hotkey: values.hotkey, favourite: values.favourite,
            quickPeek: values.quickPeek)
        settings.save(to: modules)
        close()
        onSave?(id, values.resetsRanking)
        return nil
    }

    private func save(_ values: QuicklinkSheet.Values, as link: Quicklink) -> String? {
        let saved = Quicklink(
            name: values.name, link: values.link, app: values.app, icon: values.icon, id: link.id)
        guard saved.url(for: "") != nil else { return Self.badLink }
        if let problem = bind(values.hotkey, to: link.id) {
            return problem
        }
        var item = settings[link.id]
        item.aliases = values.alias.isEmpty ? [] : [values.alias]
        item.hotkey = values.hotkey
        settings[link.id] = item
        settings.save(to: modules)
        quicklinks.update(saved)
        quicklinks.save(to: modules)
        close()
        onSave?(link.id, false)
        return nil
    }

    private func bind(_ hotkey: Shortcut?, to id: String) -> String? {
        let saved = settings[id].hotkey
        guard hotkey != saved else { return nil }
        if let registration = registrations.removeValue(forKey: id) {
            registry?.unregister(registration)
        }
        if let hotkey, !register(hotkey, for: id) {
            if let saved {
                register(saved, for: id)
            }
            return "macOS wouldn’t register this hotkey. Try another."
        }
        return nil
    }

    @discardableResult
    private func register(_ hotkey: Shortcut, for id: String) -> Bool {
        guard let registry else { return true }
        do {
            let registration = try registry.register(hotkey) { [weak self] in
                self?.onHotKey?(id)
            }
            if isAvailable(id) {
                registrations[id] = registration
            } else {
                registry.unregister(registration)
            }
            return true
        } catch {
            logger.error("Item hotkey failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
