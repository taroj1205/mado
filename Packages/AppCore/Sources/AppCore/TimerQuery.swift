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
            guard let (length, name) = Self.split(rest) else { return nil }
            self = .timer(length: length, name: name)

        case "stopwatch" where rest.isEmpty:
            self = .stopwatch

        case "pomodoro":
            self = .pomodoro(label: rest.joined(separator: " "))

        default:
            return nil
        }
    }

    private static func split(_ words: [String]) -> (length: TimeInterval?, name: String)? {
        guard !words.contains(where: isNegative) else { return nil }
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
        let label = name.joined(separator: " ")
        guard let total else { return (nil, label) }
        let whole = total.rounded()
        return whole >= 1 && whole <= longest ? (whole, label) : nil
    }

    private static func isNegative(_ word: String) -> Bool {
        word.hasPrefix("-") && Scanner(string: word).scanDouble() != nil
    }

    private static func duration(at index: Int, in words: [String]) -> (TimeInterval?, Int) {
        if let whole = duration(of: words[index]) { return (whole, oneWord) }
        guard let amount = number(words[index]), amount.isFinite else { return (nil, oneWord) }
        let unit = words.indices.contains(index + 1) ? unitSize(words[index + 1]) : nil
        return unit.map { (amount * $0, twoWords) } ?? (amount * secondsPerMinute, oneWord)
    }

    private static func number(_ word: String) -> Double? {
        word.allSatisfy { $0.isASCII && ($0.isNumber || $0 == ".") } ? Double(word) : nil
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
        return total
    }
}
