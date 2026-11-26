struct LyricsPaceCurve: Equatable, Sendable {
    struct Knot: Equatable, Sendable {
        let time: Double
        let reach: Double
    }

    private static let straight = [Knot(time: 0, reach: 0), Knot(time: 1, reach: 1)]

    private let knots: [Knot]

    init(_ beats: [LyricsPace.Beat]) {
        let spoken = beats.reduce(0) { $0 + $1.morae }
        let drawn = beats.reduce(0) { $0 + $1.width }
        guard spoken > 0, drawn > 0 else {
            knots = Self.straight
            return
        }
        var time = 0.0
        var reach = 0.0
        let running = beats.dropLast().map { beat in
            time += beat.morae / spoken
            reach += beat.width / drawn
            return Knot(time: time, reach: reach)
        }
        knots = [Knot(time: 0, reach: 0)] + running + [Knot(time: 1, reach: 1)]
    }

    init(_ words: [Lyrics.Word], from start: Double, over length: Double) {
        let widths = words.map { LyricsPace.width(of: $0.text) }
        let drawn = widths.reduce(0, +)
        guard drawn > 0, length > 0 else {
            knots = Self.straight
            return
        }
        let share = { (seconds: Double) in min(max((seconds - start) / length, 0), 1) }
        var time = 0.0
        var reach = 0.0
        let sung = zip(words, widths).flatMap { word, width in
            time = max(time, share(word.time))
            let begins = Knot(time: time, reach: reach)
            time = max(time, share(word.end))
            reach += width / drawn
            return [begins, Knot(time: time, reach: reach)]
        }
        knots = [Knot(time: 0, reach: 0)] + sung + [Knot(time: 1, reach: 1)]
    }

    func reach(at time: Double) -> Double {
        guard let next = knots.firstIndex(where: { $0.time > time }) else { return 1 }
        let lower = knots[next - 1]
        let upper = knots[next]
        let into = (time - lower.time) / (upper.time - lower.time)
        return lower.reach + (upper.reach - lower.reach) * into
    }

    func ahead(of time: Double, over seconds: Double) -> [Lyrics.Step] {
        knots.filter { $0.time > time }
            .map { Lyrics.Step(seconds: ($0.time - time) * seconds, reach: $0.reach) }
    }
}
