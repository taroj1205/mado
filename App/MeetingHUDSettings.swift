import AppCore
import AppKit

struct MeetingHUDSettings: StoredValue, Equatable {
    enum Lead: Int, CaseIterable, Codable {
        case oneMinute = 1
        case twoMinutes = 2
        case fiveMinutes = 5
        case tenMinutes = 10

        var title: String {
            self == .oneMinute ? "1 minute before" : "\(rawValue) minutes before"
        }
    }

    static let key = "meeting_hud"

    var lead = Lead.twoMinutes

    @MainActor
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let popUp = SettingsPopUp {
            let current = load(from: modules).lead
            let choices = Lead.allCases.map { lead in
                SettingsPopUp.Choice(title: lead.title, isSelected: lead == current) {
                    var settings = load(from: modules)
                    settings.lead = lead
                    settings.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return SettingsSection("Meeting reminder", [.init("Show join reminder", popUp)])
    }
}
