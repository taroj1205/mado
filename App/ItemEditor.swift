import AppCore
import AppKit
import GlassUI
import InputKit
import os
import SearchKit

@MainActor
final class ItemEditor {
    private struct Host {
        let panel: GlassPanel
        let content: NSView?
        let focus: NSView?
    }

    let sheet = ItemSheet()
    var onHotKey: ((String) -> Void)?
    var onSave: ((_ id: String, _ resetsRanking: Bool) -> Void)?

    private(set) var settings: ItemSettings
    private let logger = Log.logger("App")
    private let modules: ModuleManager?
    private let registry: HotKeyRegistry?
    private let name: (String) -> String?
    private var registrations: [String: HotKeyRegistration] = [:]
    private var host: Host?

    init(
        modules: ModuleManager?, registry: HotKeyRegistry?, name: @escaping (String) -> String?
    ) {
        settings = ItemSettings.load(from: modules)
        self.modules = modules
        self.registry = registry
        self.name = name
        sheet.onRecording = { [registry] in registry?.isSuspended = $0 }
        sheet.onCancel = { [weak self] in self?.close() }
    }

    func start() {
        for (id, hotkey) in settings.hotkeys {
            register(hotkey, for: id)
        }
    }

    func open(
        _ field: ItemSheet.Field, for item: ResultList.Item, ranking: String?,
        in panel: GlassPanel
    ) {
        close()
        host = Host(
            panel: panel, content: panel.glass.contentView, focus: panel.initialFirstResponder)
        panel.glass.contentView = sheet
        let current = settings[item.id]
        sheet.conflict = { [weak self] in self?.owner(of: $0, besides: item.id) }
        sheet.onSave = { [weak self] in self?.save($0, for: item.id) }
        sheet.show(
            item,
            values: ItemSheet.Values(
                aliases: current.aliases, hotkey: current.hotkey, favourite: current.favourite),
            ranking: ranking, opening: field)
    }

    func close() {
        guard let host else { return }
        self.host = nil
        host.panel.glass.contentView = host.content
        host.panel.initialFirstResponder = host.focus
        host.panel.makeFirstResponder(host.focus)
        (host.focus as? NSTextField)?.selectText(nil)
    }

    private func owner(of hotkey: Shortcut, besides id: String) -> String? {
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
        let saved = settings[id].hotkey
        if values.hotkey != saved {
            if let registration = registrations.removeValue(forKey: id) {
                registry?.unregister(registration)
            }
            if let hotkey = values.hotkey, !register(hotkey, for: id) {
                if let saved {
                    register(saved, for: id)
                }
                return "macOS wouldn’t register this hotkey. Try another."
            }
        }
        settings[id] = ItemSettings.Item(
            aliases: values.aliases, hotkey: values.hotkey, favourite: values.favourite)
        settings.save(to: modules)
        close()
        onSave?(id, values.resetsRanking)
        return nil
    }

    @discardableResult
    private func register(_ hotkey: Shortcut, for id: String) -> Bool {
        guard let registry else { return true }
        do {
            registrations[id] = try registry.register(hotkey) { [weak self] in
                self?.onHotKey?(id)
            }
            return true
        } catch {
            logger.error("Item hotkey failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
