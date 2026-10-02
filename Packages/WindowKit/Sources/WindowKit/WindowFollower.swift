public import CoreGraphics

@MainActor
public final class WindowFollower {
    public typealias Apply = (_ frame: CGRect, _ previous: CGRect) async -> Bool

    private static let resizeMilliseconds = 50

    public static let resizeInterval = Duration.milliseconds(resizeMilliseconds)

    private let apply: Apply
    private let interval: Duration
    private var sent: CGRect
    private var pending: (frame: CGRect, throttled: Bool)?
    private var sending: Task<Void, Never>?
    private var failed = false

    public init(from frame: CGRect, interval: Duration = resizeInterval, apply: @escaping Apply) {
        sent = frame
        self.interval = interval
        self.apply = apply
    }

    public func send(_ frame: CGRect, throttled: Bool) {
        guard !failed else { return }
        pending = (frame, throttled)
        guard sending == nil else { return }
        sending = Task { await self.drain() }
    }

    public func finish() async {
        await sending?.value
    }

    private func drain() async {
        while let next = pending {
            pending = nil
            let began = ContinuousClock.now
            guard await apply(next.frame, sent) else {
                failed = true
                break
            }
            sent = next.frame
            if next.throttled {
                try? await Task.sleep(until: began + interval)
            }
        }
        pending = nil
        sending = nil
    }
}
