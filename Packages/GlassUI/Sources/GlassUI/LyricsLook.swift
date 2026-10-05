import AppKit

public enum LyricsLook: String, CaseIterable, Sendable {
    case card = "card"
    case line = "line"
    case lyrics = "full_lyrics"

    private static let lineSize: (width: CGFloat, height: CGFloat) = (300, 44)
    private static let cardSize: (width: CGFloat, height: CGFloat) = (340, 128)
    private static let lyricsSize: (width: CGFloat, height: CGFloat) = (360, 262)

    var size: NSSize {
        let box =
            switch self {
            case .line: Self.lineSize
            case .card: Self.cardSize
            case .lyrics: Self.lyricsSize
            }
        return NSSize(width: box.width, height: box.height)
    }
}
