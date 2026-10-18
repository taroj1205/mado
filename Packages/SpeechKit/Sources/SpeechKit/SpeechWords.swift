import Foundation

public struct SpeechWords: Codable, Equatable, Sendable {
    private static let separators: Set<Character> = [",", "，", "、", "\n"]
    private static let joiner = ", "
    private static let halves = 2

    public private(set) var list: [String]

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

    public mutating func add(_ text: String) {
        self = Self(text: (list + [text]).joined(separator: "\n"))
    }

    public mutating func remove(_ word: String) {
        list.removeAll { $0 == word }
    }

    public mutating func move(_ word: String, by offset: Int) {
        guard let index = list.firstIndex(of: word), list.indices.contains(index + offset) else {
            return
        }
        list.swapAt(index, index + offset)
    }

    public mutating func move(_ word: String, before target: String?) {
        guard let index = list.firstIndex(of: word), word != target else { return }
        var rest = list
        rest.remove(at: index)
        guard let slot = target == nil ? rest.endIndex : rest.firstIndex(where: { $0 == target })
        else { return }
        rest.insert(word, at: slot)
        list = rest
    }

    func prompt(fitting budget: Int, counting tokens: (String) -> Int) -> String? {
        func sentence(_ count: Int) -> String {
            list.prefix(count).joined(separator: Self.joiner) + "."
        }
        var fits = 0
        var tooMany = list.count + 1
        while tooMany - fits > 1 {
            let middle = fits + (tooMany - fits) / Self.halves
            if tokens(sentence(middle)) <= budget {
                fits = middle
            } else {
                tooMany = middle
            }
        }
        return fits == 0 ? nil : sentence(fits)
    }
}
