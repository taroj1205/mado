import AppCore
import AppKit
import ClipboardKit
import os

@MainActor
final class ClipboardHistorySettings: NSObject {
    private typealias Retention = ClipboardStore.Retention

    private enum Days: Int, CaseIterable {
        case day = 1
        case week = 7
        case month = 30
        case quarter = 90
    }

    private enum MaximumItems: Int, CaseIterable {
        case hundred = 100
        case fiveHundred = 500
        case thousand = 1_000
        case fiveThousand = 5_000
        case tenThousand = 10_000
    }

    private static let periods: [RetentionPeriod?] =
        Days.allCases.map { RetentionPeriod($0.rawValue, .day) } + [RetentionPeriod(1, .year), nil]
    private static let itemCounts: [Int?] = MaximumItems.allCases.map(\.rawValue) + [nil]

    private let logger = Log.logger("Settings")
    private let modules: ModuleManager?
    private let sizes = NSHashTable<NSTextField>.weakObjects()

    var section: SettingsSection {
        SettingsSection(
            "Clipboard history",
            [
                .init(
                    "Keep items for",
                    popUp(\.period, Self.periods, title: Self.title, edit: Self.editPeriod)),
                .init(
                    "Maximum items",
                    popUp(\.items, Self.itemCounts, title: Self.title, edit: Self.editItems)),
            ])
    }

    var clearSection: SettingsSection {
        let label = NSTextField(labelWithString: "")
        label.textColor = .secondaryLabelColor
        sizes.add(label)
        Task { await showSize() }
        let clear = NSButton(
            title: "Clear History…", target: self, action: #selector(confirmClear))
        let row = NSStackView()
        row.setViews([label], in: .leading)
        row.setViews([clear], in: .trailing)
        return SettingsSection(content: row)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func title(_ period: RetentionPeriod?) -> String {
        period?.title ?? "Forever"
    }

    private static func title(_ items: Int?) -> String {
        items?.formatted() ?? "Unlimited"
    }

    private static func title(_ usage: ClipboardStore.Usage) -> String {
        let items = usage.items == 1 ? "1 item" : "\(usage.items.formatted()) items"
        let bytes = ByteCountFormatter.string(fromByteCount: Int64(usage.bytes), countStyle: .file)
        return "\(items) · \(bytes)"
    }

    private static func editPeriod(
        _ current: RetentionPeriod?, on window: NSWindow,
        save: @escaping (RetentionPeriod?) -> Void
    ) {
        let units = RetentionPeriod.Unit.allCases
        let sheet = LimitSheet(
            "Keep items for", count: current?.count,
            units: units.map { LimitSheet.Unit(title: $0.rawValue, range: $0.range) },
            selected: current.flatMap { units.firstIndex(of: $0.unit) } ?? 0)
        sheet.begin(on: window) { count, unit in save(RetentionPeriod(count, units[unit])) }
    }

    private static func editItems(
        _ current: Int?, on window: NSWindow, save: @escaping (Int?) -> Void
    ) {
        let sheet = LimitSheet(
            "Maximum items", count: current,
            units: [LimitSheet.Unit(title: "items", range: Retention.itemRange)], selected: 0)
        sheet.begin(on: window) { count, _ in save(count) }
    }

    private func popUp<Value: Equatable>(
        _ limit: WritableKeyPath<Retention, Value>, _ presets: [Value],
        title: @escaping (Value) -> String,
        edit: @escaping (Value, NSWindow, @escaping (Value) -> Void) -> Void
    ) -> SettingsPopUp {
        weak var control: SettingsPopUp?
        let popUp = SettingsPopUp { [weak self, modules] in
            let current = ClipboardSettings.load(from: modules).retention[keyPath: limit]
            let choice = { (value: Value) in
                SettingsPopUp.Choice(title: title(value), isSelected: value == current) {
                    try self?.save(value, to: limit)
                }
            }
            let custom = SettingsPopUp.Choice(title: "Custom…", isSelected: false) {
                guard let control, let window = unsafe control.window else { return }
                edit(current, window) { [weak control] value in
                    self?.saveCustom(value, to: limit, from: control)
                }
            }
            let saved = presets.contains(current) ? [] : [choice(current)]
            return [
                SettingsPopUp.Section(title: nil, choices: presets.map(choice)),
                SettingsPopUp.Section(title: nil, choices: saved + [custom]),
            ]
        }
        control = popUp
        popUp.isEnabled = modules != nil
        return popUp
    }

    private func saveCustom<Value: Equatable>(
        _ value: Value, to limit: WritableKeyPath<Retention, Value>, from popUp: SettingsPopUp?
    ) {
        do {
            try save(value, to: limit)
        } catch {
            logger.error("Saving a clipboard history limit failed: \(error, privacy: .public)")
            popUp?.presentError(error)
        }
        popUp?.refresh()
    }

    private func save<Value: Equatable>(
        _ value: Value, to limit: WritableKeyPath<Retention, Value>
    ) throws {
        var settings = ClipboardSettings.load(from: modules)
        guard settings.retention[keyPath: limit] != value else { return }
        settings.retention[keyPath: limit] = value
        try modules?.setValue(settings, for: ClipboardSettings.key)
        guard modules?.isEnabled(ClipboardModule.id) == true else { return }
        let retention = settings.retention
        Task { [weak self, logger] in
            do {
                let store = try ClipboardStore.standard()
                try await store.prune(keeping: retention, now: .now)
                try await store.compact()
            } catch {
                logger.error("Pruning clipboard history failed: \(error, privacy: .public)")
            }
            await self?.showSize()
        }
    }

    private func showSize() async {
        do {
            let usage = try await ClipboardStore.standard().usage()
            for label in sizes.allObjects {
                label.stringValue = Self.title(usage)
            }
        } catch {
            logger.error("Reading the clipboard history size failed: \(error, privacy: .public)")
        }
    }

    @objc
    private func confirmClear(_ sender: NSButton) {
        guard let window = unsafe sender.window else { return }
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText =
            "Every item that isn’t pinned is deleted. Pinned items are kept. "
            + "You can’t undo this action."
        let clear = alert.addButton(withTitle: "Clear History")
        clear.hasDestructiveAction = true
        clear.keyEquivalent = ""
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            self?.clear(from: sender)
        }
    }

    private func clear(from button: NSButton) {
        button.isEnabled = false
        Task { [weak self, logger] in
            do {
                try await ClipboardStore.standard().clear()
            } catch {
                logger.error("Clearing clipboard history failed: \(error, privacy: .public)")
                button.presentError(error)
            }
            button.isEnabled = true
            await self?.showSize()
        }
    }
}
