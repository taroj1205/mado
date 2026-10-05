public import Foundation

public struct Weather: Decodable, Equatable, Sendable {
    public enum Sky: Int, CaseIterable, Sendable {
        case clear = 0
        case mainlyClear = 1
        case partlyCloudy = 2
        case overcast = 3
        case fog = 45
        case drizzle = 51
        case freezingDrizzle = 56
        case rain = 61
        case heavyRain = 65
        case freezingRain = 66
        case snow = 71
        case rainShowers = 80
        case snowShowers = 85
        case thunderstorm = 95

        init?(code: Int) {
            guard let match = Self.allCases.last(where: { $0.rawValue <= code }) else {
                return nil
            }
            self = match
        }
    }

    public struct Place: Decodable, Equatable, Sendable {
        public let latitude: Double
        public let longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    private struct Search: Decodable {
        let results: [Place]

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: Keys.self)
            results = try values.decodeIfPresent([Place].self, forKey: .results) ?? []
        }
    }

    public struct Hour: Equatable, Sendable {
        public let time: Date
        public let temperature: Measurement<UnitTemperature>
        public let sky: Sky
        public let isDay: Bool
    }

    private enum Keys: String, CodingKey {
        case current = "current"
        case daily = "daily"
        case hourly = "hourly"
        case temperature = "temperature_2m"
        case code = "weather_code"
        case isDay = "is_day"
        case highs = "temperature_2m_max"
        case lows = "temperature_2m_min"
        case results = "results"
        case times = "time"
        case apparent = "apparent_temperature"
        case humidity = "relative_humidity_2m"
        case wind = "wind_speed_10m"
        case rain = "precipitation_probability_max"
        case offset = "utc_offset_seconds"
    }

    private static let forecastAPI = "https://api.open-meteo.com/v1/forecast"
    private static let searchAPI = "https://geocoding-api.open-meteo.com/v1/search"
    private static let coordinateScale = 100.0
    private static let success = 200
    private static let middle = 0.5
    private static let percent = 100.0
    private static let hoursAhead = "8"

    public let temperature: Measurement<UnitTemperature>
    public let high: Measurement<UnitTemperature>
    public let low: Measurement<UnitTemperature>
    public let sky: Sky
    public let isDay: Bool
    public let feelsLike: Measurement<UnitTemperature>?
    public let humidity: Double?
    public let wind: Measurement<UnitSpeed>?
    public let rainChance: Double?
    public let hours: [Hour]
    public let utcOffset: Int

    public var position: Double {
        let range = high.value - low.value
        guard range > 0 else { return Self.middle }
        return min(max((temperature.value - low.value) / range, 0), 1)
    }

    public init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: Keys.self)
        let now = try root.nestedContainer(keyedBy: Keys.self, forKey: .current)
        let today = try root.nestedContainer(keyedBy: Keys.self, forKey: .daily)
        guard let found = Sky(code: try now.decode(Int.self, forKey: .code)) else {
            throw DecodingError.dataCorruptedError(
                forKey: .code, in: now, debugDescription: "Unknown weather code")
        }
        guard let highest = try today.decode([Double].self, forKey: .highs).first,
            let lowest = try today.decode([Double].self, forKey: .lows).first
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .highs, in: today, debugDescription: "No forecast for today")
        }
        temperature = Measurement(
            value: try now.decode(Double.self, forKey: .temperature), unit: .celsius)
        high = Measurement(value: highest, unit: .celsius)
        low = Measurement(value: lowest, unit: .celsius)
        sky = found
        isDay = try now.decode(Int.self, forKey: .isDay) != 0
        feelsLike = try now.decodeIfPresent(Double.self, forKey: .apparent).map { degrees in
            Measurement(value: degrees, unit: .celsius)
        }
        humidity = try now.decodeIfPresent(Double.self, forKey: .humidity).map { share in
            share / Self.percent
        }
        wind = try now.decodeIfPresent(Double.self, forKey: .wind).map { speed in
            Measurement(value: speed, unit: .kilometersPerHour)
        }
        let chances = try today.decodeIfPresent([Double?].self, forKey: .rain)
        rainChance = chances?.first?.map { chance in chance / Self.percent }
        utcOffset = try root.decodeIfPresent(Int.self, forKey: .offset) ?? 0
        hours = Self.hours(in: try? root.nestedContainer(keyedBy: Keys.self, forKey: .hourly))
    }

    private static func hours(in container: KeyedDecodingContainer<Keys>?) -> [Hour] {
        guard let container,
            let times = try? container.decode([TimeInterval].self, forKey: .times),
            let temperatures = try? container.decode([Double].self, forKey: .temperature),
            let codes = try? container.decode([Int].self, forKey: .code),
            let days = try? container.decode([Int].self, forKey: .isDay)
        else { return [] }
        return zip(zip(times, temperatures), zip(codes, days)).compactMap { first, second in
            Sky(code: second.0).map { sky in
                Hour(
                    time: Date(timeIntervalSince1970: first.0),
                    temperature: Measurement(value: first.1, unit: .celsius), sky: sky,
                    isDay: second.1 != 0)
            }
        }
    }

    public static func forecast(at place: Place) async throws -> Self {
        try await JSONDecoder().decode(Self.self, from: data(from: forecastURL(at: place)))
    }

    public static func place(named name: String) async throws -> Place? {
        try await place(fromSearch: data(from: searchURL(for: name)))
    }

    static func forecastURL(at place: Place) throws -> URL {
        try url(
            forecastAPI,
            [
                "latitude": rounded(place.latitude), "longitude": rounded(place.longitude),
                "current":
                    "temperature_2m,weather_code,is_day,apparent_temperature,"
                    + "relative_humidity_2m,wind_speed_10m",
                "daily": "temperature_2m_max,temperature_2m_min,precipitation_probability_max",
                "hourly": "temperature_2m,weather_code,is_day", "timezone": "auto",
                "forecast_days": "1", "forecast_hours": hoursAhead, "timeformat": "unixtime",
            ])
    }

    static func searchURL(for name: String) throws -> URL {
        try url(searchAPI, ["name": name, "count": "1", "format": "json"])
    }

    static func place(fromSearch data: Data) throws -> Place? {
        try JSONDecoder().decode(Search.self, from: data).results.first
    }

    private static func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == success else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func rounded(_ degrees: Double) -> String {
        "\((degrees * coordinateScale).rounded() / coordinateScale)"
    }

    private static func url(_ base: String, _ query: [String: String]) throws -> URL {
        var parts = URLComponents(string: base)
        parts?.queryItems = query.sorted { $0.key < $1.key }.map(URLQueryItem.init)
        guard let url = parts?.url else { throw URLError(.badURL) }
        return url
    }
}
