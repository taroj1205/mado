import Foundation

enum TimeZones {
    private struct City {
        let zone: TimeZone
        let name: String
    }

    private static let hoursPerDay = 24
    private static let hoursPerHalfDay = 12
    private static let minutesPerHour = 60
    private static let clock = "h:mm a"
    private static let date = "EEE d MMM"
    private static let aliases: [String: (name: String, id: String)] = [
        "osaka": ("Osaka", "Asia/Tokyo"), "japan": ("Japan", "Asia/Tokyo"),
        "wellington": ("Wellington", "Pacific/Auckland"),
        "nz": ("New Zealand", "Pacific/Auckland"), "nyc": ("New York", "America/New_York"),
        "san francisco": ("San Francisco", "America/Los_Angeles"),
        "sf": ("San Francisco", "America/Los_Angeles"),
        "la": ("Los Angeles", "America/Los_Angeles"), "utc": ("UTC", "UTC"),
    ]

    private static let cities: [String: City] = {
        var table: [String: City] = [:]
        for id in TimeZone.knownTimeZoneIdentifiers {
            let name = String(id.split(separator: "/").last ?? "").replacing("_", with: " ")
            table[name.lowercased()] = TimeZone(identifier: id).map { City(zone: $0, name: name) }
        }
        for (key, alias) in aliases {
            table[key] = TimeZone(identifier: alias.id).map { City(zone: $0, name: alias.name) }
        }
        return table
    }()

    static func answer(for text: String, now: Date, local: TimeZone) -> Calculator.Answer? {
        if let name = text.wholeMatch(of: /(?:what )?(?:time (?:is it )?|now )in (.+)/)?.1 {
            guard let city = cities[String(name)] else { return nil }
            return Calculator.Answer(
                kind: "Time zones", expression: "Now in \(city.name)",
                expressionDetail: "Local \(format(now, clock, in: local))",
                result: format(now, clock, in: city.zone),
                resultDetail: day(at: now, in: city, from: local))
        }
        let here = City(zone: local, name: "Local time")
        guard
            let match = text.wholeMatch(
                of: /(\d{1,2})(?::(\d{2}))? ?(am|pm)? ([a-z ]+?)(?: (?:in|to|->) ([a-z ]+))?/),
            match.2 != nil || match.3 != nil,
            let source = cities[String(match.4)],
            let target = match.5.map({ cities[String($0)] }) ?? here,
            let hour = hour(match.1, period: match.3),
            let minute = Int(match.2 ?? "0"), minute < minutesPerHour
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.zone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        guard let time = calendar.date(from: components) else { return nil }
        return Calculator.Answer(
            kind: "Time zones",
            expression: "\(format(time, clock, in: source.zone)) \(source.name)",
            expressionDetail: format(time, date, in: source.zone),
            result: format(time, clock, in: target.zone),
            resultDetail: day(at: time, in: target, from: source.zone))
    }

    private static func hour(_ text: Substring, period: Substring?) -> Int? {
        guard let hour = Int(text) else { return nil }
        guard let period else { return hour < hoursPerDay ? hour : nil }
        guard (1...hoursPerHalfDay).contains(hour) else { return nil }
        return hour % hoursPerHalfDay + (period == "pm" ? hoursPerHalfDay : 0)
    }

    private static func day(at time: Date, in city: City, from zone: TimeZone) -> String {
        let there = format(time, "yyyy-MM-dd", in: city.zone)
        let here = format(time, "yyyy-MM-dd", in: zone)
        let relation = there == here ? "same day" : there > here ? "next day" : "previous day"
        return "\(city.name) · \(format(time, date, in: city.zone)) (\(relation))"
    }

    static func format(_ time: Date, _ pattern: String, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = pattern
        formatter.timeZone = zone
        return formatter.string(from: time)
    }
}
