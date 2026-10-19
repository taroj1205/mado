struct LyricsPaceCurve: Equatable, Sendable {
    struct Knot: Equatable, Sendable {
        let time: Double
        let reach: Double
    }

    let morae: Int
    private let knots: [Knot]

    init(_ text: String) {
        let beats = LyricsPace.beats(of: text)
        let spoken = beats.reduce(0) { $0 + $1.morae }
        let drawn = beats.reduce(0) { $0 + $1.width }
        morae = Int(spoken.rounded())
        guard spoken > 0, drawn > 0 else {
            knots = [Knot(time: 0, reach: 0), Knot(time: 1, reach: 1)]
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
