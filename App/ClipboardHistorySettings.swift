import AppCore
import AppKit
import ClipboardKit
import os

@MainActor
final class ClipboardHistorySettings: NSObject {
    private enum KeepFor: Int, CaseIterable {
        case day = 1
        case week = 7
        case month = 30
        case quarter = 90
        case year = 365
    }

    private enum MaximumItems: Int, CaseIterable {
        case hundred = 100
        case fiveHundred = 500
        case thousand = 1_000
        case fiveThousand = 5_000
        case tenThousand = 10_000
    }

    private let logger = Log.logger("Settings")
    private let modules: ModuleManager?

    var section: SettingsSection {
        SettingsSection(
            "Clipboard history",
            [
                .init(
                    "Keep items for",
                    popUp(KeepFor.allCases.map(\.rawValue), \.days, title: Self.days)),
                .init(
                    "Maximum items",
                    popUp(MaximumItems.allCases.map(\.rawValue), \.items) { $0.formatted() }),
            ])
    }

    var clearSection: SettingsSection {
        let clear = NSButton(
            title: "Clear History…", target: self, action: #selector(confirmClear))
        let row = NSStackView()
        row.setViews([clear], in: .trailing)
        return SettingsSection(content: row)
    }

    init(modules: ModuleManager?) {
        self.modules = modules
    }

    private static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    private func popUp(
        _ choices: [Int], _ limit: WritableKeyPath<ClipboardStore.Retention, Int>,
        title: @escaping (Int) -> String
    ) -> SettingsPopUp {
        let popUp = SettingsPopUp { [modules] in
            let current = ClipboardSettings.load(from: modules).retention[keyPath: limit]
            let values = choices.contains(current) ? choices : (choices + [current]).sorted()
            let entries = values.map { value in
                SettingsPopUp.Choice(title: title(value), isSelected: value == current) {
                    var settings = ClipboardSettings.load(from: modules)
                    guard settings.retention[keyPath: limit] != value else { return }
                    settings.retention[keyPath: limit] = value
                    try modules?.setValue(settings, for: ClipboardSettings.key)
                    try modules?.restart(ClipboardModule.id)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: entries)]
        }
        popUp.isEnabled = modules != nil
        return popUp
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
        Task { [logger] in
            do {
                try await ClipboardStore.standard().clear()
            } catch {
                logger.error("Clearing clipboard history failed: \(error, privacy: .public)")
                button.presentError(error)
            }
            button.isEnabled = true
        }
    }
}
