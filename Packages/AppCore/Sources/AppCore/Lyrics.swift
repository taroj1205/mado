public import Foundation

public struct Lyrics: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        case lrclib
        case kuGou
        case betterLyrics

        public var name: String {
            switch self {
            case .lrclib: "LRCLIB"
            case .kuGou: "KuGou"
            case .betterLyrics: "Better Lyrics"
            }
        }
    }

    public struct Word: Equatable, Sendable {
        public let text: String
        public let time: TimeInterval
        public let duration: TimeInterval

        var end: TimeInterval {
            time + duration
        }

        public init(text: String, time: TimeInterval, duration: TimeInterval) {
            self.text = text
            self.time = time
            self.duration = duration
        }
    }

    public struct Line: Equatable, Sendable {
        public let time: TimeInterval?
        public let text: String
        public let words: [Word]

        public init(time: TimeInterval?, text: String, words: [Word] = []) {
            self.time = time
            self.text = text
            self.words = words
        }
    }

    public struct Step: Equatable, Sendable {
        public let seconds: Double
        public let reach: Double

        public init(seconds: Double, reach: Double) {
            self.seconds = seconds
            self.reach = reach
        }
    }

    public struct Moment: Equatable, Sendable {
        public let index: Int
        public let progress: Double
        public let remaining: Double?
        public let ahead: [Step]
    }

    private static let secondsPerMinute = 60.0
    private static let lastLineSeconds = 5.0
    private static let timestampParts = 2
    private static let measuredLines = 8
    private static let shortestLine = 1.0
    private static let shortestBreak = 6.0
    private static let medianDivisor = 2

    public let lines: [Line]
    public let isSynced: Bool
    public let source: Source
    private let paces: [LyricsPaceCurve]
    private let sungLimits: [TimeInterval]

    public init(lines: [Line], isSynced: Bool, source: Source = .lrclib) {
        self.lines = lines
        self.isSynced = isSynced
        self.source = source
        let beats =
            isSynced ? lines.map { $0.words.isEmpty ? LyricsPace.beats(of: $0.text) : [] } : []
        sungLimits =
            isSynced ? Self.sungLimits(for: lines, morae: beats.map(LyricsPace.morae)) : []
        paces = zip(lines, zip(beats, sungLimits)).map { line, guess in
            guard let start = line.time, !line.words.isEmpty else {
                return LyricsPaceCurve(guess.0)
            }
            return LyricsPaceCurve(line.words, from: start, over: guess.1)
        }
    }

    init(sung lines: [Line], source: Source) {
        let breaks = zip(lines, lines.dropFirst().map(\.time) + [nil]).flatMap { line, next in
            guard let next, let end = line.words.map(\.end).max(), next - end >= Self.shortestBreak
            else { return [line] }
            return [line, Line(time: end, text: "")]
        }
        self.init(lines: breaks, isSynced: true, source: source)
    }

    public init?(synced: String?, plain: String?) {
        if let synced, case let timed = Self.timedLines(synced), !timed.isEmpty {
            self.init(lines: timed, isSynced: true)
        } else if let plain, case let rows = Self.plainLines(plain), !rows.isEmpty {
            self.init(lines: rows, isSynced: false)
        } else {
            return nil
        }
    }

    private static func plainLines(_ text: String) -> [Line] {
        let rows = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { Line(time: nil, text: $0.trimmingCharacters(in: .whitespaces)) }
        guard let first = rows.firstIndex(where: { !$0.text.isEmpty }),
            let last = rows.lastIndex(where: { !$0.text.isEmpty })
        else { return [] }
        return Array(rows[first...last])
    }

    private static func timedLines(_ text: String) -> [Line] {
        text.split(whereSeparator: \.isNewline)
            .flatMap { row -> [Line] in
                var rest = Substring(row)
                var stamps: [TimeInterval] = []
                while rest.first == "[", let close = rest.firstIndex(of: "]") {
                    let tag = rest[rest.index(after: rest.startIndex)..<close]
                    if let stamp = timestamp(tag) { stamps.append(stamp) }
                    rest = rest[rest.index(after: close)...]
                }
                let words = rest.trimmingCharacters(in: .whitespaces)
                return stamps.map { Line(time: $0, text: words) }
            }
            .enumerated()
            .sorted { ($0.element.time ?? 0, $0.offset) < ($1.element.time ?? 0, $1.offset) }
            .map(\.element)
    }

    private static func sungLimits(for lines: [Line], morae: [Int]) -> [TimeInterval] {
        let rates = zip(lines.indices, lines.dropFirst()).compactMap { index, next -> Double? in
            guard morae[index] > 0, let start = lines[index].time, let end = next.time, end > start
            else { return nil }
            return (end - start) / Double(morae[index])
        }
        let typical =
            rates.count >= measuredLines ? rates.sorted()[rates.count / medianDivisor] : nil
        return lines.indices.map { index in
            if let sung = sungLength(of: index, in: lines) { return sung }
            guard let typical, morae[index] > 0 else { return .infinity }
            return max(Double(morae[index]) * typical, shortestLine)
        }
    }

    private static func sungLength(of index: Int, in lines: [Line]) -> TimeInterval? {
        guard let start = lines[index].time, let end = lines[index].words.map(\.end).max(),
            end > start
        else { return nil }
        let next = lines[(index + 1)...].first { ($0.time ?? start) > start }?.time
        return min(end, next ?? end) - start
    }

    private static func timestamp(_ tag: Substring) -> TimeInterval? {
        let parts = tag.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == timestampParts, let minutes = Int(parts[0]), minutes >= 0,
            let seconds = Double(parts[1]), seconds >= 0, parts[1].first?.isNumber == true
        else { return nil }
        return Double(minutes) * secondsPerMinute + seconds
    }

    public func index(at time: TimeInterval) -> Int? {
        guard isSynced else { return nil }
        let next = lines.firstIndex { ($0.time ?? 0) > time } ?? lines.count
        return next == 0 ? nil : next - 1
    }

    func nextLineStart(after time: TimeInterval) -> TimeInterval? {
        guard isSynced else { return nil }
        return lines.first { ($0.time ?? 0) > time }?.time
    }

    public func moment(at time: TimeInterval, duration: TimeInterval?) -> Moment? {
        guard let index = index(at: time), let start = lines[index].time else { return nil }
        let following = lines.dropFirst(index + 1).first { ($0.time ?? start) > start }?.time
        let end = following ?? max(duration ?? 0, start + Self.lastLineSeconds)
        let length = min(end - start, sungLimits[index])
        let into = min(max(time - start, 0), length)
        let sung = into / length
        return Moment(
            index: index, progress: paces[index].reach(at: sung), remaining: length - into,
            ahead: paces[index].ahead(of: sung, over: length))
    }
}
