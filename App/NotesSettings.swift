import AppCore
import AppKit
import Carbon.HIToolbox

struct NotesSettings: StoredValue, Equatable {
    static let key = "notes"
    private static let hotkey = Shortcut(
        keyCode: UInt32(kVK_ANSI_N), modifiers: [.command, .option])

    var assignedDefaultHotKey = false

    init() {
        assignedDefaultHotKey = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        assignedDefaultHotKey =
            try values.decodeIfPresent(Bool.self, forKey: .assignedDefaultHotKey)
            ?? assignedDefaultHotKey
    }

    @MainActor
    static func assignDefaultHotKey(in editor: ItemEditor, modules: ModuleManager?) {
        var settings = load(from: modules)
        guard !settings.assignedDefaultHotKey, modules?.isEnabled(NotesModule.id) == true else {
            return
        }
        editor.assignDefaults([(NoteBoard.commandID, hotkey)])
        settings.assignedDefaultHotKey = true
        settings.save(to: modules)
    }

    @MainActor
    static func section(_ recorder: HotKeyPopover) -> SettingsSection {
        SettingsSection(
            "Sticky notes",
            [.init("New note", recorder.button(for: NoteBoard.commandID, named: "New Note"))])
    }
}
