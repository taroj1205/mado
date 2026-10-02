public import Foundation

public struct Usage: Codable, Equatable, Sendable {
    struct Entry: Codable, Equatable, Sendable {
        var weight: Double
        var date: Date
        var count: Int

        init(weight: Double, date: Date, count: Int) {
            self.weight = weight
            self.date = date
            self.count = count
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            weight = try container.decode(Double.self, forKey: .weight)
            date = try container.decode(Date.self, forKey: .date)
            count =
                try container.decodeIfPresent(Int.self, forKey: .count)
                ?? max(1, Int(weight.rounded()))
        }
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
        let count = (entries[id]?.count ?? 0) + 1
        entries = entries.filter { self.weight(of: $0.key, at: now) >= Self.forgottenWeight }
        entries[id] = Entry(weight: weight, date: now, count: count)
    }

    public mutating func forget(_ id: String) {
        entries[id] = nil
    }

    public func summary(of id: String, at now: Date, in calendar: Calendar = .current) -> String? {
        guard let entry = entries[id] else { return nil }
        let style = Date.FormatStyle(
            locale: calendar.locale ?? .autoupdatingCurrent, calendar: calendar,
            timeZone: calendar.timeZone)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let day =
            if calendar.isDate(entry.date, inSameDayAs: now) {
                "today"
            } else if calendar.isDate(entry.date, inSameDayAs: yesterday) {
                "yesterday"
            } else {
                entry.date.formatted(style.month().day())
            }
        let times = entry.count == 1 ? "1 time" : "\(entry.count) times"
        return "Opened \(times) · last \(day), \(entry.date.formatted(style.hour().minute()))"
    }

    private func weight(of id: String, at now: Date) -> Double {
        guard let entry = entries[id] else { return 0 }
        let age = max(0, now.timeIntervalSince(entry.date))
        return entry.weight * exp2(-age / Self.halfLife)
    }
}
