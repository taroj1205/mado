import AppKit

extension WidgetTrack {
    static func heading(_ track: WidgetGrid.Track) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let line = NSMutableAttributedString(
            string: track.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: short.title, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: style,
            ])
        if !track.artist.isEmpty {
            line.append(
                NSAttributedString(
                    string: "  \(track.artist)",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: short.artist),
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .paragraphStyle: style,
                    ]))
        }
        return line
    }
}
