import AppCore
public import Foundation
import os

@MainActor
public final class ExchangeRateFeed {
    private static let cache = URL.applicationSupportDirectory.appending(
        path: "Mado/eurofxref-daily.xml")
    private static let ecb = URL(
        string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")

    public private(set) var rates: ExchangeRates?
    public var onChange: (() -> Void)?
    public var interval: TimeInterval? {
        didSet { schedule() }
    }

    private(set) var nextFetch: Date?
    private let logger = Log.logger("ExchangeRateFeed")
    private let cache: URL
    private let source: URL?
    private var attempted: Date?
    private var fetching = false
    private var timer: Task<Void, Never>?

    public convenience init() {
        self.init(cache: Self.cache, source: Self.ecb)
    }

    init(cache: URL, source: URL?) {
        self.cache = cache
        self.source = source
    }

    public func start(every interval: TimeInterval?) {
        rates = ExchangeRates(contentsOf: cache)
        self.interval = interval
    }

    public func refresh() async throws {
        guard !fetching, let source else { return }
        fetching = true
        attempted = .now
        defer {
            fetching = false
            schedule()
        }
        let (data, _) = try await URLSession.shared.data(from: source)
        guard let fresh = ExchangeRates(ecb: data, fetched: .now) else {
            throw URLError(.cannotParseResponse)
        }
        rates = fresh
        onChange?()
        do {
            try FileManager.default.createDirectory(
                at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cache, options: .atomic)
        } catch {
            logger.error("Caching exchange rates failed: \(error, privacy: .public)")
        }
    }

    private func schedule() {
        guard !fetching else { return }
        timer?.cancel()
        let last = [rates?.fetched, attempted].compactMap(\.self).max()
        nextFetch = interval.map { last?.addingTimeInterval($0) ?? .now }
        guard let nextFetch else { return }
        timer = Task { [weak self, logger] in
            guard (try? await Task.sleep(for: .seconds(nextFetch.timeIntervalSinceNow))) != nil
            else { return }
            do {
                try await self?.refresh()
            } catch {
                logger.error("Refreshing exchange rates failed: \(error, privacy: .public)")
            }
        }
    }
}
