import Foundation
import Testing

@testable import AppCore

@Suite struct WeatherTests {
    private let first = 1_790_000_000.0

    private func forecast(code: Int = 2, isDay: Int = 1, highs: String = "[17.1]") -> Data {
        Data(
            """
            {"current_units":{"temperature_2m":"°C"},
            "current":{"time":"2026-10-05T13:00","interval":900,"temperature_2m":15.4,
            "weather_code":\(code),"is_day":\(isDay)},
            "daily":{"time":["2026-10-05"],"temperature_2m_max":\(highs),
            "temperature_2m_min":[11.0]}}
            """.utf8)
    }

    private func hourlyForecast(_ hourly: String? = nil) -> Data {
        let rows =
            hourly
                ?? """
                "hourly":{"time":[\(first),\(first + 3_600),\(first + 7_200),\(first + 10_800)],
                "temperature_2m":[15.4,16.0,17.2,14.1],"weather_code":[2,0,3,61],
                "is_day":[1,1,1,0]},
                """
        return Data(
            """
            {"utc_offset_seconds":46800,
            "current":{"time":1790000000,"interval":900,"temperature_2m":15.4,
            "weather_code":2,"is_day":1},
            \(rows)
            "daily":{"time":[1789999000],"temperature_2m_max":[17.1],
            "temperature_2m_min":[11.0]}}
            """.utf8)
    }

    private func decode(_ data: Data) throws -> Weather {
        try JSONDecoder().decode(Weather.self, from: data)
    }

    @Test func readsTheCurrentTemperatureSkyAndTodaysRange() throws {
        let weather = try decode(forecast())
        #expect(weather.temperature == Measurement(value: 15.4, unit: .celsius))
        #expect(weather.high == Measurement(value: 17.1, unit: .celsius))
        #expect(weather.low == Measurement(value: 11.0, unit: .celsius))
        #expect(weather.sky == .partlyCloudy)
        #expect(weather.isDay)
    }

    @Test(arguments: [
        (0, Weather.Sky.clear), (1, .mainlyClear), (2, .partlyCloudy), (3, .overcast),
        (45, .fog), (48, .fog), (53, .drizzle), (57, .freezingDrizzle), (63, .rain),
        (65, .heavyRain), (67, .freezingRain), (77, .snow), (82, .rainShowers),
        (86, .snowShowers), (99, .thunderstorm),
    ])
    func mapsWeatherCodesToSkies(code: Int, sky: Weather.Sky) throws {
        #expect(try decode(forecast(code: code)).sky == sky)
    }

    @Test func placesNowWithinTodaysRange() throws {
        #expect(abs(try decode(forecast()).position - (15.4 - 11.0) / (17.1 - 11.0)) < 0.0001)
        #expect(try decode(forecast(highs: "[11.0]")).position == 0.5)
        #expect(try decode(forecast(highs: "[14.0]")).position == 1)
    }

    @Test func nightIsKept() throws {
        #expect(try !decode(forecast(isDay: 0)).isDay)
    }

    @Test func aNegativeCodeOrMissingRangeIsRejected() {
        #expect(throws: DecodingError.self) { try decode(forecast(code: -1)) }
        #expect(throws: DecodingError.self) { try decode(forecast(highs: "[]")) }
    }

    @Test func readsTheHoursAheadInThePlacesTimeZone() throws {
        let weather = try decode(hourlyForecast())
        #expect(weather.timeZone.secondsFromGMT() == 46_800)
        #expect(weather.hours.map(\.sky) == [.partlyCloudy, .clear, .overcast, .rain])
        #expect(weather.hours.map(\.isDay) == [true, true, true, false])
        #expect(weather.hours[2].temperature == Measurement(value: 17.2, unit: .celsius))
        #expect(weather.hours[1].start == Date(timeIntervalSince1970: first + 3_600))
    }

    @Test func listsHoursFromTheOneThatContainsNow() throws {
        let weather = try decode(hourlyForecast())
        let now = Date(timeIntervalSince1970: first + 3_600 + 600)
        #expect(weather.hours(from: now, count: 2).map(\.sky) == [.clear, .overcast])
        #expect(weather.hours(from: now, count: 9).count == 3)
        #expect(weather.hours(from: now.addingTimeInterval(86_400), count: 2).isEmpty)
    }

    @Test func aReplyWithoutHoursStillReadsToday() throws {
        let weather = try decode(forecast())
        #expect(weather.hours.isEmpty)
        #expect(weather.sky == .partlyCloudy)
    }

    @Test func mismatchedHourlyListsKeepTheCompleteHours() throws {
        let weather = try decode(
            hourlyForecast(
                """
                "hourly":{"time":[\(first),\(first + 3_600)],"temperature_2m":[15.4],
                "weather_code":[2,0],"is_day":[1,1]},
                """))
        #expect(weather.hours.count == 1)
    }

    @Test func anErrorReplyIsRejected() {
        let reply = Data(#"{"error":true,"reason":"Latitude must be in range"}"#.utf8)
        #expect(throws: DecodingError.self) { try decode(reply) }
    }

    @Test func findsTheFirstPlace() throws {
        let reply = Data(
            #"{"results":[{"name":"Auckland","latitude":-36.84853,"longitude":174.76349}]}"#.utf8)
        let place = try Weather.place(fromSearch: reply)
        #expect(place == Weather.Place(latitude: -36.84853, longitude: 174.76349))
    }

    @Test func anUnknownPlaceIsNil() throws {
        #expect(try Weather.place(fromSearch: Data(#"{"generationtime_ms":0.9}"#.utf8)) == nil)
    }

    @Test func sendsOnlyARoundedPosition() throws {
        let url = try Weather.forecastURL(at: .init(latitude: -36.84853, longitude: 174.76349))
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = query.queryItems ?? []
        #expect(items.first { $0.name == "latitude" }?.value == "-36.85")
        #expect(items.first { $0.name == "longitude" }?.value == "174.76")
        #expect(items.first { $0.name == "timeformat" }?.value == "unixtime")
        #expect(query.host == "api.open-meteo.com")
    }

    @Test func searchesForTheTypedName() throws {
        let url = try Weather.searchURL(for: "São Paulo")
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(query.queryItems?.first { $0.name == "name" }?.value == "São Paulo")
        #expect(query.host == "geocoding-api.open-meteo.com")
    }
}
