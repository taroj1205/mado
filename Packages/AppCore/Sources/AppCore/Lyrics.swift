public import Foundation

public struct Lyrics: Equatable, Sendable {
    public struct Line: Equatable, Sendable {
        public let time: TimeInterval?
        public let text: String

        public init(time: TimeInterval?, text: String) {
            self.time = time
            self.text = text
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
    private static let paceSlack = 2.0
    private static let medianDivisor = 2

    public let lines: [Line]
    public let isSynced: Bool
    private let paces: [LyricsPaceCurve]
    private let sungLimits: [TimeInterval]

    public init(lines: [Line], isSynced: Bool) {
        self.lines = lines
        self.isSynced = isSynced
        paces = isSynced ? lines.map { LyricsPaceCurve($0.text) } : []
        sungLimits = isSynced ? Self.sungLimits(for: lines, curves: paces) : []
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

    private static func sungLimits(
        for lines: [Line], curves: [LyricsPaceCurve]
    ) -> [TimeInterval] {
        let morae = curves.map(\.morae)
        let rates = zip(lines.indices, lines.dropFirst()).compactMap { index, next -> Double? in
            guard morae[index] > 0, let start = lines[index].time, let end = next.time, end > start
            else { return nil }
            return (end - start) / Double(morae[index])
        }
        guard rates.count >= measuredLines else {
            return Array(repeating: .infinity, count: lines.count)
        }
        let typical = rates.sorted()[rates.count / medianDivisor]
        return morae.map { count in
            count > 0 ? max(Double(count) * typical * paceSlack, shortestLine) : .infinity
        }
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
