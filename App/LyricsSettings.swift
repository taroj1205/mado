import AppCore
import Foundation
import GlassUI

struct LyricsSettings: StoredValue, Equatable {
    enum HideDelay: Int, CaseIterable {
        case five = 5
        case minute = 60
        case never = 0
        case now = -1
        case ten = 10
        case thirty = 30

        static let allCases: [Self] = [.now, .five, .ten, .thirty, .minute, .never]

        var title: String {
            switch self {
            case .five, .ten, .thirty: "\(rawValue) seconds"
            case .minute: "1 minute"
            case .now: "Immediately"
            case .never: "Never"
            }
        }

        var seconds: TimeInterval? {
            switch self {
            case .never: nil
            case .now: 0
            case .five, .ten, .thirty, .minute: TimeInterval(rawValue)
            }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case corner = "corner"
        case dockSide = "dock_side"
        case hideDelay = "hide_after"
        case hidesInSharing = "hides_in_sharing"
        case look = "look"
        case lookup = "lookup"
        case pin = "pin"
        case players = "players"
        case screen = "screen"
    }

    static let key = "lyrics"

    var lookup: Bool
    var pin: LyricsPin?
    var look: LyricsLook
    var corner: LyricsCorner
    var dockSide: LyricsSide
    var screen: LauncherScreen
    var hideDelay: HideDelay
    var hidesInSharing: Bool
    var players: Set<MusicPlayer.Player>

    var isActive: Bool {
        pin != nil && lookup && !players.isEmpty
    }

    var spot: LyricsSpot? {
        pin.map { LyricsSpot(pin: $0, corner: corner, side: dockSide) }
    }

    init() {
        lookup = false
        pin = nil
        look = .line
        corner = .bottomTrailing
        dockSide = .trailing
        screen = .mouse
        hideDelay = .ten
        hidesInSharing = true
        players = Set(MusicPlayer.Player.allCases)
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        lookup = try values.decodeIfPresent(Bool.self, forKey: .lookup) ?? lookup
        pin = try values.decodeIfPresent(String.self, forKey: .pin)
            .flatMap(LyricsPin.init(rawValue:))
        look =
            try values.decodeIfPresent(String.self, forKey: .look)
            .flatMap(LyricsLook.init(rawValue:)) ?? look
        corner =
            try values.decodeIfPresent(String.self, forKey: .corner)
            .flatMap(LyricsCorner.init(rawValue:)) ?? corner
        dockSide =
            try values.decodeIfPresent(String.self, forKey: .dockSide)
            .flatMap(LyricsSide.init(rawValue:)) ?? dockSide
        screen = LauncherScreen(json: try values.decodeIfPresent(JSONValue.self, forKey: .screen))
        hideDelay =
            try values.decodeIfPresent(Int.self, forKey: .hideDelay)
            .flatMap(HideDelay.init(rawValue:)) ?? hideDelay
        hidesInSharing =
            try values.decodeIfPresent(Bool.self, forKey: .hidesInSharing) ?? hidesInSharing
        players =
            try values.decodeIfPresent([String].self, forKey: .players)
            .map { names in Set(names.compactMap(MusicPlayer.Player.init(rawValue:))) } ?? players
    }

    mutating func place(at spot: LyricsSpot) {
        pin = spot.pin
        corner = spot.corner ?? corner
        dockSide = spot.side ?? dockSide
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(lookup, forKey: .lookup)
        try values.encodeIfPresent(pin?.rawValue, forKey: .pin)
        try values.encode(look.rawValue, forKey: .look)
        try values.encode(corner.rawValue, forKey: .corner)
        try values.encode(dockSide.rawValue, forKey: .dockSide)
        try values.encode(screen.json, forKey: .screen)
        try values.encode(hideDelay.rawValue, forKey: .hideDelay)
        try values.encode(hidesInSharing, forKey: .hidesInSharing)
        try values.encode(players.map(\.rawValue).sorted(), forKey: .players)
    }
}
