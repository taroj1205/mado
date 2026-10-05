public import Foundation

public enum TimerQuery: Equatable, Sendable {
    case pomodoro(label: String)
    case stopwatch
    case timer(length: TimeInterval?, name: String)

    private static let secondsPerMinute = 60.0
    private static let secondsPerHour = 3_600.0
    private static let longest = 100 * secondsPerHour
    private static let oneWord = 1
    private static let twoWords = 2
    private static let hours: Set<String> = ["h", "hr", "hrs", "hour", "hours"]
    private static let minutes: Set<String> = ["m", "min", "mins", "minute", "minutes"]
    private static let seconds: Set<String> = ["s", "sec", "secs", "second", "seconds"]

    public init?(_ query: String) {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let keyword = words.first?.lowercased() else { return nil }
        let rest = Array(words.dropFirst())
        switch keyword {
        case "timer":
            let (length, name) = Self.split(rest)
            self = .timer(length: length, name: name)

        case "stopwatch" where rest.isEmpty:
            self = .stopwatch

        case "pomodoro":
            self = .pomodoro(label: rest.joined(separator: " "))

        default:
            return nil
        }
    }

    private static func split(_ words: [String]) -> (length: TimeInterval?, name: String) {
        var total: TimeInterval?
        var name: [String] = []
        var index = 0
        while index < words.count {
            let (found, used) = duration(at: index, in: words)
            if let found {
                total = (total ?? 0) + found
            } else {
                name.append(words[index])
            }
            index += used
        }
        let valid = total.flatMap { $0 > 0 && $0 <= longest ? $0 : nil }
        return (valid, name.joined(separator: " "))
    }

    private static func duration(at index: Int, in words: [String]) -> (TimeInterval?, Int) {
        if let whole = duration(of: words[index]) { return (whole, oneWord) }
        guard let amount = Double(words[index]), amount.isFinite, amount >= 0 else {
            return (nil, oneWord)
        }
        let unit = words.indices.contains(index + 1) ? unitSize(words[index + 1]) : nil
        return unit.map { (amount * $0, twoWords) } ?? (amount * secondsPerMinute, oneWord)
    }

    private static func unitSize(_ text: String) -> Double? {
        let unit = text.lowercased()
        return if hours.contains(unit) {
            secondsPerHour
        } else if minutes.contains(unit) {
            secondsPerMinute
        } else if seconds.contains(unit) {
            1
        } else {
            nil
        }
    }

    private static func duration(of word: String) -> TimeInterval? {
        let scanner = Scanner(string: word)
        scanner.charactersToBeSkipped = nil
        var total = 0.0
        while !scanner.isAtEnd {
            guard let value = scanner.scanDouble(), value.isFinite, value >= 0,
                let unit = scanner.scanCharacters(from: .letters), let size = unitSize(unit)
            else { return nil }
            total += value * size
        }
        return total > 0 ? total : nil
    }
}
