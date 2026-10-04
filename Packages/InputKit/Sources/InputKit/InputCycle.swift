struct InputCycle {
    private struct Pending {
        let from: String?
        let target: String
        let since: ContinuousClock.Instant
    }

    private static let settle: Duration = .seconds(1)

    private var pending: Pending?

    mutating func next(
        after current: String?, in ids: [String], at now: ContinuousClock.Instant
    ) -> String? {
        if let waiting = pending, waiting.from != current || now - waiting.since >= Self.settle {
            pending = nil
        }
        let base = pending?.target ?? current
        let target = base.flatMap(ids.firstIndex).map { ids[($0 + 1) % ids.count] } ?? ids.first
        pending = target.map { Pending(from: current, target: $0, since: now) }
        return target
    }
}
