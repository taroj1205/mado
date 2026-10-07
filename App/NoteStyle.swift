import AppKit

enum NoteStyle {
    static let size = CGSize(width: side, height: side)
    static let radius: CGFloat = 20
    static let barHeight: CGFloat = 34
    static let inset = NSSize(width: insetX, height: insetY)
    static let ink = NSColor(srgbRed: inkRed, green: inkRed, blue: inkBlue, alpha: 1)
    static let paper = NSColor(
        srgbRed: 1, green: paperGreen, blue: paperBlue, alpha: paperAlpha)
    static let rim = NSColor.white.withAlphaComponent(rimAlpha)
    private static let side: CGFloat = 300
    private static let insetX: CGFloat = 12
    private static let insetY: CGFloat = 2
    private static let inkRed: CGFloat = 0.114
    private static let inkBlue: CGFloat = 0.122
    private static let paperGreen: CGFloat = 0.839
    private static let paperBlue: CGFloat = 0.4
    private static let paperAlpha: CGFloat = 0.92
    private static let rimAlpha: CGFloat = 0.18
    private static let titleSize: CGFloat = 16
    private static let bodySize: CGFloat = 13.5
    private static let lineHeight: CGFloat = 20
    private static let paragraphGap: CGFloat = 6

    static func titleLength(of text: String) -> Int {
        text.prefix { !$0.isNewline }.utf16.count
    }

    static func restyle(_ storage: NSTextStorage) {
        let text = storage.string
        storage.beginEditing()
        storage.setAttributes(
            attributes(title: false), range: NSRange(location: 0, length: text.utf16.count))
        if !text.isEmpty {
            let line = min(titleLength(of: text) + 1, text.utf16.count)
            storage.setAttributes(
                attributes(title: true), range: NSRange(location: 0, length: line))
        }
        storage.endEditing()
    }

    static func typingAttributes(in text: String, caret: Int) -> [NSAttributedString.Key: Any] {
        attributes(title: caret <= titleLength(of: text))
    }

    private static func attributes(title: Bool) -> [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = title ? 0 : lineHeight
        style.paragraphSpacing = paragraphGap
        return [
            .font: title
                ? NSFont.systemFont(ofSize: titleSize, weight: .bold)
                : NSFont.systemFont(ofSize: bodySize),
            .foregroundColor: ink,
            .paragraphStyle: style,
        ]
    }
}
