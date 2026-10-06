import Foundation

public enum WidgetQuery {
    public enum Kind: CaseIterable, Sendable {
        case battery
        case calendar
        case lyrics
        case system
        case weather
    }

    private static let shortest = 3
    private static let keywords: [Kind: [String]] = [
        .weather: ["weather", "forecast"], .battery: ["battery"],
        .system: ["cpu", "memory", "ram", "processor"], .calendar: ["calendar"],
        .lyrics: ["lyrics"],
    ]

    public static func kinds(for query: String) -> [Kind] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard text.count >= shortest else { return [] }
        return Kind.allCases.filter { kind in
            keywords[kind]?.contains { $0.hasPrefix(text) } == true
        }
    }
}
