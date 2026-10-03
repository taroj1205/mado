import AppCore
import AppKit
import ClipboardKit

extension SettingsPage {
    private enum KeepDays: Int, CaseIterable {
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

    static let clipboardHistory = "Clipboard history"

    static func clipboard(_ context: Context) -> [SettingsSection] {
        [
            SettingsSection(
                clipboardHistory,
                [
                    .init(
                        "Keep items for",
                        retentionPopUp(
                            context.modules, \.days, choices: KeepDays.allCases.map(\.rawValue)
                        ) { days in
                            days == 1 ? "1 day" : "\(days) days"
                        }),
                    .init(
                        "Maximum items",
                        retentionPopUp(
                            context.modules, \.items,
                            choices: MaximumItems.allCases.map(\.rawValue)
                        ) { items in items.formatted() }),
                ]),
            context.ignoredApps.section,
            SettingsSection(content: clearHistoryButton()),
        ]
    }

    private static func retentionPopUp(
        _ modules: ModuleManager?, _ field: WritableKeyPath<ClipboardStore.Retention, Int>,
        choices: [Int], title: @escaping (Int) -> String
    ) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = ClipboardSettings.load(from: modules).retention[keyPath: field]
            let values = Set(choices + [current]).sorted()
            let items = values.map { value in
                SettingsPopUp.Choice(title: title(value), isSelected: value == current) {
                    var settings = ClipboardSettings.load(from: modules)
                    settings.retention[keyPath: field] = value
                    try modules?.setValue(settings, for: ClipboardSettings.key)
                    try modules?.restart(ClipboardModule.id)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: items)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }

    private static func clearHistoryButton() -> NSView {
        let button = SettingsButton("Clear History…") {
            guard confirmsClearingHistory() else { return }
            try await ClipboardStore.standard().clear()
        }
        let row = NSStackView()
        row.setViews([button], in: .trailing)
        return row
    }

    private static func confirmsClearingHistory() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText =
            "Every saved item is deleted, including pinned ones. You can’t undo this."
        let clear = alert.addButton(withTitle: "Clear History")
        clear.hasDestructiveAction = true
        clear.keyEquivalent = ""
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
