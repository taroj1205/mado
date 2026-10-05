import Foundation
import Testing

@testable import AppCore

@Suite struct WeatherTests {
    private let detailed = Data(
        """
        {"utc_offset_seconds":46800,
        "current":{"time":1791189900,"interval":900,"temperature_2m":12.6,"weather_code":0,
        "is_day":0,"apparent_temperature":10.1,"relative_humidity_2m":77,"wind_speed_10m":14.5},
        "hourly":{"time":[1791187200,1791190800,1791194400],"temperature_2m":[12.8,12.6,12.1],
        "weather_code":[0,2,61],"is_day":[0,0,1]},
        "daily":{"time":[1791154800],"temperature_2m_max":[17.1],"temperature_2m_min":[11.0],
        "precipitation_probability_max":[35]}}
        """.utf8)

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

    @Test func readsHowItFeelsHowHumidHowWindyAndTheChanceOfRain() throws {
        let weather = try decode(detailed)
        #expect(weather.feelsLike == Measurement(value: 10.1, unit: .celsius))
        #expect(weather.humidity == 0.77)
        #expect(weather.wind == Measurement(value: 14.5, unit: .kilometersPerHour))
        #expect(weather.rainChance == 0.35)
        #expect(weather.utcOffset == 46_800)
    }

    @Test func readsTheHoursFromNowOnAndSkipsAnyWithAnUnknownCode() throws {
        let weather = try decode(detailed)
        #expect(weather.hours.map(\.sky) == [.clear, .partlyCloudy, .rain])
        #expect(weather.hours.map(\.isDay) == [false, false, true])
        #expect(weather.hours.first?.time == Date(timeIntervalSince1970: 1_791_187_200))
        #expect(weather.hours.last?.temperature == Measurement(value: 12.1, unit: .celsius))
        let broken =
            String(bytes: detailed, encoding: .utf8)?
            .replacing("[0,2,61]", with: "[0,-1,61]") ?? ""
        #expect(try decode(Data(broken.utf8)).hours.count == 2)
    }

    @Test func aReplyWithoutTheExtrasStillGivesTheBasics() throws {
        let weather = try decode(forecast())
        #expect(weather.feelsLike == nil)
        #expect(weather.humidity == nil)
        #expect(weather.wind == nil)
        #expect(weather.rainChance == nil)
        #expect(weather.hours.isEmpty)
        #expect(weather.utcOffset == 0)
    }

    @Test func askForTheNextHoursAsUnixTimes() throws {
        let url = try Weather.forecastURL(at: .init(latitude: 1, longitude: 2))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            .queryItems
        #expect(items?.first { $0.name == "timeformat" }?.value == "unixtime")
        #expect(items?.first { $0.name == "forecast_hours" }?.value == "8")
        #expect(items?.first { $0.name == "hourly" }?.value?.contains("weather_code") == true)
    }

    @Test func nightIsKept() throws {
        #expect(try !decode(forecast(isDay: 0)).isDay)
    }

    @Test func aNegativeCodeOrMissingRangeIsRejected() {
        #expect(throws: DecodingError.self) { try decode(forecast(code: -1)) }
        #expect(throws: DecodingError.self) { try decode(forecast(highs: "[]")) }
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
        #expect(query.host == "api.open-meteo.com")
    }

    @Test func searchesForTheTypedName() throws {
        let url = try Weather.searchURL(for: "São Paulo")
        let query = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(query.queryItems?.first { $0.name == "name" }?.value == "São Paulo")
        #expect(query.host == "geocoding-api.open-meteo.com")
    }
}
