import AppKit
import SearchKit

enum SidebarText {
    static func styled(
        _ text: SettingsSearch.Text, size: CGFloat, color: NSColor, matchColor: NSColor,
        weight: NSFont.Weight
    ) -> NSAttributedString {
        let matches = Set(text.matches)
        let plain: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color,
        ]
        let bold: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .bold), .foregroundColor: matchColor,
        ]
        let styled = NSMutableAttributedString()
        for (offset, character) in text.string.enumerated() {
            styled.append(
                NSAttributedString(
                    string: String(character), attributes: matches.contains(offset) ? bold : plain))
        }
        return styled
    }
}
