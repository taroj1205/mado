import AppCore
import Foundation
import os

@MainActor
public final class ExchangeRateFeed {
    private static let cache = URL.applicationSupportDirectory.appending(
        path: "Mado/eurofxref-daily.xml")
    private static let ecb = URL(
        string: "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml")
    private static let refreshSeconds = 21_600

    public private(set) var rates: ExchangeRates?
    public var onChange: (() -> Void)?

    private let logger = Log.logger("ExchangeRateFeed")
    private let cache: URL
    private let source: URL?

    public convenience init() {
        self.init(cache: Self.cache, source: Self.ecb)
    }

    init(cache: URL, source: URL?) {
        self.cache = cache
        self.source = source
    }

    public func start() {
        rates = ExchangeRates(contentsOf: cache)
        Task { [weak self] in
            while await self?.refresh() != nil {
                try? await Task.sleep(for: .seconds(Self.refreshSeconds))
            }
        }
    }

    func refresh() async {
        guard let source else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: source)
            guard let fresh = ExchangeRates(ecb: data, fetched: .now) else {
                logger.error("The exchange rate source sent no rates")
                return
            }
            rates = fresh
            onChange?()
            try FileManager.default.createDirectory(
                at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: cache, options: .atomic)
        } catch {
            logger.error("Refreshing exchange rates failed: \(error, privacy: .public)")
        }
    }
}
