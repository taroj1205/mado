import AppCore
import AppKit
import SpeechKit

@MainActor
enum DictationWordsSettings {
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let field = SettingsTextField(
            placeholder: "Mado, SwiftUI, Kanary",
            read: { DictationSettings.load(from: modules).words.text },
            write: { text in
                var settings = DictationSettings.load(from: modules)
                settings.words = SpeechWords(text: text)
                settings.save(to: modules)
            })
        field.isEnabled = modules != nil
        return SettingsSection(
            "Custom words", [.init("Words", field)],
            footer: SettingsSection.footnote(
                "Names and terms you say, separated by commas. Dictation spells them the way "
                    + "you write them here. When the list is too long for Whisper, the words "
                    + "written last are left out. Parakeet models ignore it."),
            accessory: nil)
    }
}
