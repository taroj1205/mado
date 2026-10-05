import AppCore
import AppKit

extension LyricsSettings {
    private static let footerSize: CGFloat = 12
    private static let captionSize: CGFloat = 11
    private static let site = "lrclib.net"
    private static let note = "Off until you turn it on"

    private static var footer: NSAttributedString {
        let text = NSMutableAttributedString(
            string: "When a song starts, Mado sends its title, artist, album and length to "
                + "\(site) to find the lyrics. Nothing else leaves your Mac, and nothing is sent "
                + "while this is off.",
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

    @MainActor
    static func sections(_ editor: LyricsSettingsEditor) -> [SettingsSection] {
        [
            SettingsSection(
                "Lyrics", note: note,
                [
                    .init("Show lyrics", editor.toggle(\.lookup), icon: nil) {
                        "Adds a line to Now Playing and the Lyrics widget and pane."
                    },
                    .init("Keep on screen", editor.pinPopUp(), icon: nil) {
                        "Stays after the launcher closes."
                    },
                    .init("Size", editor.sizeControl()),
                    .init("Show on", editor.screenPopUp()),
                    .init("Hide when paused for", editor.hidePopUp()),
                    .init("Hide in screen sharing", editor.toggle(\.hidesInSharing)),
                ]),
            SettingsSection(
                "Lookup",
                [
                    .init("Players", editor.playerChecks()),
                    .init("Source", caption(site)),
                    .init("Kept on this Mac", caption("this song only")),
                ], footer: footer, accessory: nil),
        ]
    }

    @MainActor
    private static func caption(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .monospacedSystemFont(ofSize: captionSize, weight: .regular)
        label.textColor = .secondaryLabelColor
        return label
    }
}
