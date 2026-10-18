import Foundation

public struct SpeechWords: Codable, Equatable, Sendable {
    private static let separators: Set<Character> = [",", "，", "、", "\n"]
    private static let joiner = ", "

    public private(set) var list: [String]

    public var text: String {
        list.joined(separator: Self.joiner)
    }

    public init() {
        list = []
    }

    public init(text: String) {
        var seen = Set<String>()
        list = text.split { Self.separators.contains($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.singleValueContainer().decode([String].self)
        self.init(text: saved.joined(separator: "\n"))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(list)
    }

    func prompt(fitting budget: Int, counting tokens: (String) -> Int) -> String? {
        var kept = list[...]
        while !kept.isEmpty {
            let prompt = kept.joined(separator: Self.joiner) + "."
            if tokens(prompt) <= budget { return prompt }
            kept = kept.dropLast()
        }
        return nil
    }
}
