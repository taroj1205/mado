import Foundation

public enum LyricsSpot: Hashable, Sendable {
    case corner(LyricsCorner)
    case desktop
    case dock(LyricsSide)
    case island
    case menuBar
    case menus

    public static let all: [Self] = [
        .island, .corner(.topLeading), .corner(.topTrailing), .menus, .menuBar,
        .corner(.bottomLeading), .corner(.bottomTrailing), .desktop, .dock(.leading),
        .dock(.trailing),
    ]

    public var pin: LyricsPin {
        switch self {
        case .corner: .corner
        case .desktop: .desktop
        case .dock: .dock
        case .island: .island
        case .menuBar: .menuBar
        case .menus: .menus
        }
    }

    public var corner: LyricsCorner? {
        guard case .corner(let corner) = self else { return nil }
        return corner
    }

    public var side: LyricsSide? {
        guard case .dock(let side) = self else { return nil }
        return side
    }

    public var title: String {
        switch self {
        case .corner(let corner): "Corner card · \(corner.name.capitalized)"
        case .dock(let side): "Next to the Dock · \(side.title)"
        case .desktop, .island, .menuBar, .menus: pin.title
        }
    }

    public var detail: String {
        switch self {
        case .corner:
            "A glass card that floats above your windows. Drag it to another corner."

        case .desktop:
            "Large type along the bottom of the desktop, behind your windows."

        case .dock:
            "Beside the Dock, wrapping so every word shows. "
                + "It moves to the other side when this one is full."

        case .island:
            "A glass pill at the top centre of the screen, above every window."

        case .menuBar:
            "The current line in the menu bar, in place of Mado’s icon."

        case .menus:
            "The quiet stretch of the menu bar after the front app’s menus."
        }
    }

    public init(pin: LyricsPin, corner: LyricsCorner, side: LyricsSide) {
        self =
            switch pin {
            case .corner: .corner(corner)
            case .desktop: .desktop
            case .dock: .dock(side)
            case .island: .island
            case .menuBar: .menuBar
            case .menus: .menus
            }
    }
}
