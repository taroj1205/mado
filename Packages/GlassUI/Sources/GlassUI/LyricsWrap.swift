import AppKit

struct LyricsWrap {
    let rects: [CGRect]

    var height: CGFloat {
        rects.reduce(0) { $0 + $1.height }
    }

    init(_ text: String, font: NSFont, width: CGFloat, lines: Int) {
        let storage = NSTextStorage(
            attributedString: Self.string(text, font: font, color: .labelColor))
        let container = NSTextContainer(
            size: NSSize(width: max(width, 1), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = lines
        container.lineBreakMode = .byTruncatingTail
        let manager = NSLayoutManager()
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        let range = manager.glyphRange(for: container)
        var found: [CGRect] = []
        unsafe manager.enumerateLineFragments(forGlyphRange: range) { rect, used, _, _, _ in
            found.append(CGRect(x: used.minX, y: rect.minY, width: used.width, height: rect.height))
        }
        rects = found
    }

    static func lineHeight(of font: NSFont) -> CGFloat {
        ceil(font.ascender - font.descender + font.leading)
    }

    static func string(_ text: String, font: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph(font)])
    }

    private static func paragraph(_ font: NSFont) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = lineHeight(of: font)
        style.maximumLineHeight = lineHeight(of: font)
        return style
    }
}
