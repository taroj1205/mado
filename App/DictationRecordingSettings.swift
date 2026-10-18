import AppCore
import AppKit

@MainActor
enum DictationRecordingSettings {
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let keeps = SettingsSwitch(
            read: { DictationSettings.load(from: modules).keepsRecordings },
            write: { keeps in
                var settings = DictationSettings.load(from: modules)
                settings.keepsRecordings = keeps
                settings.save(to: modules)
            })
        keeps.isEnabled = modules != nil
        let folder = SettingsButton("Show in Finder") {
            let directory = DictationLog.standard.directory
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            NSWorkspace.shared.open(directory)
        }
        return SettingsSection(
            "Recordings",
            [
                .init("Keep recent recordings", keeps),
                .init("Recordings folder", folder),
            ],
            footer: SettingsSection.footnote(
                "Keeps the audio and the text of your last \(DictationLog.limit) dictations "
                    + "on this Mac, so you can check what was misheard."),
            accessory: nil)
    }
}
