import AppCore

@MainActor
final class SystemFeed {
    private static let warmUpSeconds = 0.5
    private static let intervalSeconds = 2.0

    private let sampler = SystemSampler()
    private var ticking: Task<Void, Never>?

    func start(_ receive: @escaping @MainActor (SystemStats) -> Void) {
        stop()
        ticking = Task { [sampler] in
            var wait = Self.warmUpSeconds
            while !Task.isCancelled {
                let stats = await sampler.sample()
                guard !Task.isCancelled else { return }
                receive(stats)
                try? await Task.sleep(for: .seconds(wait))
                wait = Self.intervalSeconds
            }
        }
    }

    func stop() {
        ticking?.cancel()
        ticking = nil
    }
}
