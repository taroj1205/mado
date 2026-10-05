public import Foundation

public enum LyricsPlace: Equatable, Sendable {
    case corner(LyricsCorner)
    case desktop
    case island
    case menuBar(anchor: NSRect)
}
