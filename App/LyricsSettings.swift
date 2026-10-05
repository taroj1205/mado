import AppCore
import AppKit

struct LyricsSettings: StoredValue, Equatable {
    static let key = "lyrics"
    private static let footerSize: CGFloat = 12
    private static let site = "lrclib.net"

    private static var footer: NSAttributedString {
        let text = NSMutableAttributedString(
            string: "Mado sends the song title, artist, album and length to \(site) "
                + "to find lyrics. Nothing is sent while this is off.",
            attributes: [
                .font: NSFont.systemFont(ofSize: footerSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        if let range = text.string.range(of: site) {
            text.addAttribute(
                .link, value: "https://\(site)/", range: NSRange(range, in: text.string))
        }
        return text
    }

    var lookup: Bool

    init() {
        lookup = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        lookup = try values.decodeIfPresent(Bool.self, forKey: .lookup) ?? lookup
    }

    @MainActor
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let toggle = SettingsSwitch(
            read: { load(from: modules).lookup },
            write: { enabled in
                var settings = load(from: modules)
                settings.lookup = enabled
                settings.save(to: modules)
            })
        toggle.isEnabled = modules != nil
        return SettingsSection(
            "Lyrics", [.init("Look up lyrics", toggle)], footer: footer, accessory: nil)
    }
}
