import AppCore
import AppKit

@MainActor
enum DictationLiveTextSettings {
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let shows = SettingsSwitch(
            read: { DictationSettings.load(from: modules).showsLiveText },
            write: { shows in
                var settings = DictationSettings.load(from: modules)
                settings.showsLiveText = shows
                settings.save(to: modules)
            })
        shows.isEnabled = modules != nil
        return SettingsSection(
            "While you talk",
            [.init("Show live text", shows)],
            footer: SettingsSection.footnote(
                "Shows the words heard so far in the pill. It transcribes again every second, "
                    + "which uses more power. Only the text after you let go is pasted."),
            accessory: nil)
    }
}
