import Foundation

public struct Emoji: Equatable, Sendable {
    enum Match: Comparable {
        case fullName
        case nameWords
        case keywords
        case prefixes
    }

    public enum Tone: String, CaseIterable, Codable, Sendable {
        case standard = "default"
        case light = "light"
        case mediumLight = "medium_light"
        case medium = "medium"
        case mediumDark = "medium_dark"
        case dark = "dark"

        public var title: String {
            switch self {
            case .standard: "Default"
            case .light: "Light"
            case .mediumLight: "Medium-Light"
            case .medium: "Medium"
            case .mediumDark: "Medium-Dark"
            case .dark: "Dark"
            }
        }

        var modifier: Unicode.Scalar? {
            switch self {
            case .standard: nil
            case .light: "\u{1F3FB}"
            case .mediumLight: "\u{1F3FC}"
            case .medium: "\u{1F3FD}"
            case .mediumDark: "\u{1F3FE}"
            case .dark: "\u{1F3FF}"
            }
        }
    }

    private static let variation: Unicode.Scalar = "\u{FE0F}"

    public let character: String
    public let name: String
    public let group: Int
    public let takesTone: Bool
    let nameWords: [Substring]
    let keywords: [Substring]

    public var shortcode: String {
        ":" + Self.words(of: name).joined(separator: "_") + ":"
    }

    init(character: String, name: String, keywords: String, group: Int, takesTone: Bool) {
        self.character = character
        self.name = name
        self.group = group
        self.takesTone = takesTone
        nameWords = Self.words(of: name)
        self.keywords = Self.words(of: keywords)
    }

    static func words(of text: String) -> [Substring] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }
    }

    public func toned(_ tone: Tone) -> String {
        guard takesTone, let modifier = tone.modifier,
            let first = character.unicodeScalars.first
        else { return character }
        var rest = character.unicodeScalars.dropFirst()
        if rest.first == Self.variation {
            rest = rest.dropFirst()
        }
        var scalars = String.UnicodeScalarView([first, modifier])
        scalars.append(contentsOf: rest)
        return String(scalars)
    }

    func match(_ query: [Substring]) -> Match? {
        if nameWords == query { return .fullName }
        if query.allSatisfy(nameWords.contains) { return .nameWords }
        if query.allSatisfy({ word in nameWords.contains(word) || keywords.contains(word) }) {
            return .keywords
        }
        let prefixed = query.allSatisfy { word in
            nameWords.contains { $0.hasPrefix(word) } || keywords.contains { $0.hasPrefix(word) }
        }
        return prefixed ? .prefixes : nil
    }
}
