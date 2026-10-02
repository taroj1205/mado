struct LoadMeter {
    struct Counters {
        let busy: UInt32
        let idle: UInt32
        let received: UInt64
    }

    private static let shortestSeconds = 0.2
    private static let longestSeconds = 10.0

    private(set) var cpu: Double?
    private(set) var download: Double?
    private var last: (counters: Counters, time: ContinuousClock.Instant)?

    mutating func record(_ counters: Counters, at time: ContinuousClock.Instant) {
        guard let last else {
            self.last = (counters, time)
            return
        }
        let seconds = last.time.duration(to: time) / .seconds(1)
        guard seconds >= Self.shortestSeconds else { return }
        self.last = (counters, time)
        guard seconds <= Self.longestSeconds else { return }
        let busy = Double(counters.busy &- last.counters.busy)
        let total = busy + Double(counters.idle &- last.counters.idle)
        if total > 0 {
            cpu = busy / total
        }
        let received = counters.received.subtractingReportingOverflow(last.counters.received)
        download = received.overflow ? 0 : Double(received.partialValue) / seconds
    }
}
