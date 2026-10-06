import AppCore
import EventKit
import Foundation

@MainActor
final class UpNextFeed {
    private struct Cached {
        let found: [CalendarAgenda.Found]
        let day: Date
        let fetched: ContinuousClock.Instant
    }

    private static let lifetimeSeconds = 300
    private static let lifetime: Duration = .seconds(lifetimeSeconds)

    private var cached: Cached?
    private var generation = 0

    func refreshOnChange(
        in context: ModuleContext, _ refresh: @escaping @MainActor () -> Void
    ) {
        context.observe(
            .EKEventStoreChanged, on: .default, reading: \.name
        ) { [weak self] _ in
            self?.invalidate()
            refresh()
        }
    }

    func found(around now: Date) async -> [CalendarAgenda.Found] {
        let day = Calendar.current.startOfDay(for: now)
        if let cached, cached.day == day, ContinuousClock.now - cached.fetched < Self.lifetime {
            return cached.found
        }
        let started = generation
        let found = await CalendarAgenda.upNext(around: now)
        if generation == started {
            cached = Cached(found: found, day: day, fetched: .now)
        }
        return found
    }

    private func invalidate() {
        generation += 1
        cached = nil
    }
}
