public import Foundation

public struct AnswerSettings: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case calculator = "calculator"
        case units = "units"
        case currency = "currency"
        case timeZones = "time_zones"
        case dates = "dates"
        case colours = "colours"
        case dictionary = "dictionary"
    }

    public enum Refresh: String, Codable, CaseIterable, Sendable {
        case hourly = "1h"
        case sixHourly = "6h"
        case daily = "1d"
        case manual = "manual"

        private static let hour: TimeInterval = 3_600
        private static let sixHours: TimeInterval = 21_600
        private static let day: TimeInterval = 86_400

        public var seconds: TimeInterval? {
            switch self {
            case .hourly: Self.hour
            case .sixHourly: Self.sixHours
            case .daily: Self.day
            case .manual: nil
            }
        }
    }

    public enum UnitSystem: String, Codable, CaseIterable, Sendable {
        case metric = "metric"
        case usCustomary = "us"

        public static func measures(in locale: Locale) -> Self {
            locale.measurementSystem == .us ? .usCustomary : .metric
        }

        public static func temperature(in locale: Locale) -> Self {
            UnitTemperature(forLocale: locale) == .fahrenheit ? .usCustomary : .metric
        }
    }

    public var currency: String?
    public var refresh: Refresh
    public var temperature: UnitSystem?
    public var measures: UnitSystem?
    private var off: [Kind]

    public init() {
        currency = nil
        refresh = .sixHourly
        temperature = nil
        measures = nil
        off = []
    }

    public func shows(_ kind: Kind) -> Bool {
        !off.contains(kind)
    }

    public mutating func show(_ kind: Kind, _ shown: Bool) {
        off = Kind.allCases.filter { $0 == kind ? !shown : off.contains($0) }
    }

    func currency(in locale: Locale) -> String? {
        currency ?? locale.currency?.identifier
    }

    func temperature(in locale: Locale) -> UnitSystem {
        temperature ?? .temperature(in: locale)
    }

    func measures(in locale: Locale) -> UnitSystem {
        measures ?? .measures(in: locale)
    }
}
