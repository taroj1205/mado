public import Foundation

public struct Usage: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var weight: Double
        var date: Date
    }

    static let halfLife: TimeInterval = 1_209_600
    static let bonusPerDoubling = Double(Fuzzy.wordStartBonus)
    static let forgottenWeight = 0.05

    private(set) var entries: [String: Entry]

    public init() {
        entries = [:]
    }

    public func bonus(for id: String, at now: Date) -> Int {
        Int((Self.bonusPerDoubling * log2(1 + weight(of: id, at: now))).rounded())
    }

    public mutating func record(_ id: String, at now: Date) {
        let weight = weight(of: id, at: now) + 1
        entries = entries.filter { self.weight(of: $0.key, at: now) >= Self.forgottenWeight }
        entries[id] = Entry(weight: weight, date: now)
    }

    private func weight(of id: String, at now: Date) -> Double {
        guard let entry = entries[id] else { return 0 }
        let age = max(0, now.timeIntervalSince(entry.date))
        return entry.weight * exp2(-age / Self.halfLife)
    }
}
