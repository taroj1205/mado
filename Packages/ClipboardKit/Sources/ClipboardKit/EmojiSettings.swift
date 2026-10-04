public struct EmojiSettings: Codable, Equatable, Sendable {
    public static let recentLimit = 12

    public var recent: [String]
    public var tone: Emoji.Tone

    public init() {
        recent = []
        tone = .standard
    }

    public mutating func use(_ emoji: String) {
        recent.removeAll { $0 == emoji }
        recent.insert(emoji, at: 0)
        recent = Array(recent.prefix(Self.recentLimit))
    }
}
