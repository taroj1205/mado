import AppCore
import AppKit
import GlassUI

extension Widgets {
    private typealias Look = (condition: String, symbol: String)

    private static let weatherApp = "com.apple.weather"
    private static let openWeather = "Open Weather"
    private static let unknownSky: Look = ("", "cloud")
    private static let looks: [Weather.Sky: Look] = [
        .clear: ("Clear", "sun.max"), .mainlyClear: ("Mostly clear", "sun.max"),
        .partlyCloudy: ("Partly cloudy", "cloud.sun"), .overcast: ("Cloudy", "cloud"),
        .fog: ("Fog", "cloud.fog"), .drizzle: ("Drizzle", "cloud.drizzle"),
        .freezingDrizzle: ("Freezing drizzle", "cloud.sleet"), .rain: ("Rain", "cloud.rain"),
        .heavyRain: ("Heavy rain", "cloud.heavyrain"),
        .freezingRain: ("Freezing rain", "cloud.sleet"), .snow: ("Snow", "cloud.snow"),
        .rainShowers: ("Showers", "cloud.sun.rain"), .snowShowers: ("Snow showers", "cloud.snow"),
        .thunderstorm: ("Thunderstorms", "cloud.bolt.rain"),
    ]
    private static let freezing = -10.0
    private static let cold = 0.0
    private static let cool = 10.0
    private static let mild = 18.0
    private static let warm = 24.0
    private static let hot = 30.0
    private static let scorching = 38.0
    private static let scale: [(celsius: Double, colour: NSColor)] = [
        (freezing, .systemIndigo), (cold, .systemBlue), (cool, .systemTeal), (mild, .systemGreen),
        (warm, .systemYellow), (hot, .systemOrange), (scorching, .systemRed),
    ]
    private static let nightSymbols: [Weather.Sky: String] = [
        .clear: "moon.stars", .mainlyClear: "moon.stars", .partlyCloudy: "cloud.moon",
        .rainShowers: "cloud.moon.rain",
    ]

    static func widget(for state: WeatherFeed.State) -> WidgetGrid.Widget {
        let name = name(of: weather)
        switch state {
        case .loading:
            return .init(
                id: weather, name: name, content: .loading(title: name), action: openWeather,
                spoken: "\(name): loading")

        case .needsPermission:
            return .init(
                id: weather, name: name,
                content: .permission(title: name, request: "Allow location", reason: ""),
                action: "Allow Location Access",
                spoken: "\(name): allow location access to show local weather")

        case .denied:
            return notice("Location off", "Or set a city", "Open Location Settings")

        case .notFound(let city):
            return notice("Not found", city, openWeather)

        case .failed:
            return notice("Can’t load", "Will retry", openWeather)

        case .ready(let now):
            return ready(now)
        }
    }

    private static func ready(_ now: Weather) -> WidgetGrid.Widget {
        let look = looks[now.sky] ?? unknownSky
        let high = degrees(now.high)
        let low = degrees(now.low)
        return .init(
            id: weather, name: name(of: weather), value: degrees(now.temperature),
            detail: look.condition, action: openWeather,
            spoken: "\(name(of: weather)): \(degrees(now.temperature, width: .wide)), "
                + "\(look.condition.lowercased()), high \(high), low \(low)",
            symbol: now.isDay ? look.symbol : nightSymbols[now.sky] ?? look.symbol,
            span: .init(
                low: low, high: high, position: now.position, cold: colour(of: now.low),
                warm: colour(of: now.high)))
    }

    private static func colour(of temperature: Measurement<UnitTemperature>) -> NSColor {
        let celsius = temperature.converted(to: .celsius).value
        guard let upper = scale.firstIndex(where: { $0.celsius >= celsius }) else {
            return scale.last?.colour ?? .systemRed
        }
        guard upper > 0 else { return scale[upper].colour }
        let (below, above) = (scale[upper - 1], scale[upper])
        let fraction = (celsius - below.celsius) / (above.celsius - below.celsius)
        return below.colour.blended(withFraction: fraction, of: above.colour) ?? above.colour
    }

    private static func notice(
        _ headline: String, _ detail: String, _ action: String
    ) -> WidgetGrid.Widget {
        let name = name(of: weather)
        return .init(
            id: weather, name: name,
            content: .notice(title: name, headline: headline, detail: detail), action: action,
            spoken: "\(name): \(headline). \(detail)")
    }

    private static func degrees(
        _ temperature: Measurement<UnitTemperature>,
        width: Measurement<UnitTemperature>.FormatStyle.UnitWidth = .narrow
    ) -> String {
        let unit = UnitTemperature(forLocale: .current)
        let value = temperature.converted(to: unit).value.rounded()
        return Measurement(value: value == 0 ? 0 : value, unit: unit).formatted(
            .measurement(
                width: width, usage: .asProvided, hidesScaleName: true,
                numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    func refreshWeather() {
        if shown.contains(Self.weather) {
            weatherFeed.refresh(for: city)
        } else {
            weatherFeed.cancel()
        }
    }

    func weatherAction(titled title: String) -> CommandAction {
        switch weatherFeed.state {
        case .needsPermission:
            return CommandAction(id: "allow", title: title) { [weatherFeed] in
                weatherFeed.requestPermission()
            }

        case .denied:
            return CommandAction(id: "open", title: title) {
                NSWorkspace.shared.open(PermissionManager.settingsURL(for: .location))
            }

        default:
            return Self.openApp(Self.weatherApp, titled: title)
        }
    }
}
