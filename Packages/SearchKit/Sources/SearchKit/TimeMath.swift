import Foundation

enum TimeMath {
    private static let minutesPerHour = 60
    private static let minutesPerDay = 1_440
    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3_600
    private static let secondsPerDay = 86_400
    private static let secondsPerWeek = 604_800
    private static let hoursPerHalfDay = 12
    private static let daysPerWeek = 7
    private static let hourDigits = 100.0
    private static let targetDigits = 1_000.0
    private static let secondsLimit = 1e12
    private static let locale = Locale(identifier: "en_GB")
    private static let durationUnits: [String: Int] = [
        "w": secondsPerWeek, "week": secondsPerWeek, "weeks": secondsPerWeek,
        "d": secondsPerDay, "day": secondsPerDay, "days": secondsPerDay,
        "h": secondsPerHour, "hr": secondsPerHour, "hrs": secondsPerHour,
        "hour": secondsPerHour, "hours": secondsPerHour,
        "m": secondsPerMinute, "min": secondsPerMinute, "mins": secondsPerMinute,
        "minute": secondsPerMinute, "minutes": secondsPerMinute,
        "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1,
    ]
    private static let targets: [String: Int] = [
        "weeks": secondsPerWeek, "days": secondsPerDay, "hours": secondsPerHour,
        "minutes": secondsPerMinute, "seconds": 1,
    ]
    private static let minuteDigits = 2

    static func answer(for text: String, now: Date, local: TimeZone) -> Calculator.Answer? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = local
        return hoursBetween(text) ?? timeOfDay(text) ?? duration(text)
            ?? date(text, now: now, calendar: calendar)
            ?? countdown(text, now: now, calendar: calendar)
    }

    private static func hoursBetween(_ text: String) -> Calculator.Answer? {
        guard let match = text.wholeMatch(of: /(?:from )?(.+?) ?(?:to|until|till|–|-) ?(.+)/),
            let start = clock(match.1), let end = clock(match.2)
        else { return nil }
        let overnight = end < start
        let minutes = end - start + (overnight ? minutesPerDay : 0)
        let hours = (Double(minutes) / Double(minutesPerHour) * hourDigits).rounded() / hourDigits
        return Calculator.Answer(
            kind: "Time", expression: "\(clockLabel(start)) → \(clockLabel(end))",
            expressionDetail: overnight ? "Hours between (overnight)" : "Hours between",
            result: durationLabel(minutes * secondsPerMinute),
            resultDetail:
                "\(Calculator.format(hours)) hours · \(Calculator.format(Double(minutes))) minutes")
    }

    private static func timeOfDay(_ text: String) -> Calculator.Answer? {
        guard let match = text.wholeMatch(of: /(\d{1,2}(?::\d{2})? ?(?:am|pm)?) ?([+-]) ?(.+)/),
            let start = clock(match.1), let length = seconds(in: String(match.3)).flatMap(whole)
        else { return nil }
        let instant = start * secondsPerMinute + (match.2 == "+" ? length : -length)
        let end = floored(instant, by: secondsPerMinute)
        let days = floored(end, by: minutesPerDay)
        let shift =
            switch days {
            case 0: "Same day"
            case 1: "Next day"
            case -1: "Previous day"
            default: "\(count(abs(days), "day")) \(days > 0 ? "later" : "earlier")"
            }
        return Calculator.Answer(
            kind: "Time",
            expression: "\(clockLabel(start)) \(match.2) \(durationLabel(length))",
            expressionDetail: "Time of day", result: clockLabel(end), resultDetail: shift)
    }

    private static func duration(_ text: String) -> Calculator.Answer? {
        var body = Substring(text)
        var target: (name: Substring, seconds: Int)?
        let suffix = text.wholeMatch(of: /(.+) (?:in|to|as) ([a-z]+)/)
        if let suffix, let unit = targets[String(suffix.2)] {
            body = suffix.1
            target = (suffix.2, unit)
        }
        let expression = String(body)
        var factor: Double?
        if let match = body.wholeMatch(of: /(.+?) ?[*x×] ?([\d.]+)/) {
            guard let value = Double(match.2) else { return nil }
            body = match.1
            factor = value
        }
        let terms = body.replacing("-", with: "+-").split(
            separator: "+", omittingEmptySubsequences: false)
        guard terms.count > 1 || target != nil || factor != nil, let sum = sum(of: terms),
            let total = whole(sum * (factor ?? 1))
        else { return nil }
        if let target {
            let value = (Double(total) / Double(target.seconds) * targetDigits).rounded()
            return Calculator.Answer(
                kind: "Duration", expression: expression, expressionDetail: durationLabel(total),
                result: "\(Calculator.format(value / targetDigits)) \(target.name)",
                resultDetail: durationLabel(total))
        }
        let hours = (Double(total) / Double(secondsPerHour) * hourDigits).rounded() / hourDigits
        let minutes = (Double(total) / Double(secondsPerMinute)).rounded()
        return Calculator.Answer(
            kind: "Duration", expression: expression, expressionDetail: "Duration",
            result: durationLabel(total),
            resultDetail:
                "\(Calculator.format(hours)) hours · \(Calculator.format(minutes)) minutes")
    }

    private static func date(
        _ text: String, now: Date, calendar: Calendar
    ) -> Calculator.Answer? {
        let today = calendar.startOfDay(for: now)
        guard let day = DayQuery.offset(text, from: today, calendar: calendar) else { return nil }
        return Calculator.Answer(
            kind: "Dates", expression: text.prefix(1).uppercased() + text.dropFirst(),
            expressionDetail: "From \(label(today, "EEE, d MMM yyyy", calendar))",
            result: label(day, "d MMM yyyy", calendar), resultDetail: label(day, "EEEE", calendar))
    }

    private static func countdown(
        _ text: String, now: Date, calendar: Calendar
    ) -> Calculator.Answer? {
        let today = calendar.startOfDay(for: now)
        guard let target = DayQuery.until(text, after: today, calendar: calendar),
            let days = calendar.dateComponents([.day], from: today, to: target).day
        else { return nil }
        return Calculator.Answer(
            kind: "Dates", expression: "Until \(label(target, "d MMM", calendar))",
            expressionDetail: label(target, "EEE, d MMM yyyy", calendar),
            result: count(days, "day"),
            resultDetail:
                "\(count(days / daysPerWeek, "week")) \(count(days % daysPerWeek, "day"))")
    }

    private static func clock(_ text: Substring) -> Int? {
        guard let match = text.wholeMatch(of: /(\d{1,2})(?::(\d{2}))? ?(am|pm)?/),
            match.2 != nil || match.3 != nil, let hour = Int(match.1)
        else { return nil }
        let minute = match.2.flatMap { Int($0) } ?? 0
        guard minute < minutesPerHour else { return nil }
        guard let meridiem = match.3 else {
            let time = hour * minutesPerHour + minute
            return time < minutesPerDay ? time : nil
        }
        guard (1...hoursPerHalfDay).contains(hour) else { return nil }
        let base = hour % hoursPerHalfDay + (meridiem == "pm" ? hoursPerHalfDay : 0)
        return base * minutesPerHour + minute
    }

    private static func clockLabel(_ minutes: Int) -> String {
        let time = (minutes % minutesPerDay + minutesPerDay) % minutesPerDay
        let hour = time / minutesPerHour
        let minute = (time % minutesPerHour).formatted(
            .number.precision(.integerLength(minuteDigits)))
        let shown = (hour + hoursPerHalfDay - 1) % hoursPerHalfDay + 1
        return "\(shown):\(minute) \(hour < hoursPerHalfDay ? "AM" : "PM")"
    }

    private static func sum(of terms: [Substring]) -> Double? {
        var total = 0.0
        for term in terms {
            let negative = term.hasPrefix("-")
            let unsigned = term.dropFirst(negative ? 1 : 0).trimmingCharacters(in: .whitespaces)
            guard let value = seconds(in: unsigned) else { return nil }
            total += negative ? -value : value
        }
        return total
    }

    private static func seconds(in text: String) -> Double? {
        guard text.wholeMatch(of: /(?:\d+(?:\.\d+)? ?[a-z]+ ?)+/) != nil else { return nil }
        var total = 0.0
        for match in text.matches(of: /(\d+(?:\.\d+)?) ?([a-z]+)/) {
            guard let value = Double(match.1), let unit = durationUnits[String(match.2)] else {
                return nil
            }
            total += value * Double(unit)
        }
        return total
    }

    private static func durationLabel(_ seconds: Int) -> String {
        let length = abs(seconds)
        let days = length / secondsPerDay
        let parts = [
            (days, "d"),
            (length % secondsPerDay / secondsPerHour, "h"),
            (length % secondsPerHour / secondsPerMinute, "min"),
            (days == 0 ? length % secondsPerMinute : 0, "s"),
        ]
        let shown = parts.filter { $0.0 != 0 }.map { "\($0.0) \($0.1)" }
        return shown.isEmpty ? "0 min" : (seconds < 0 ? "−" : "") + shown.joined(separator: " ")
    }

    private static func whole(_ value: Double) -> Int? {
        abs(value) < secondsLimit ? Int(value.rounded()) : nil
    }

    private static func floored(_ value: Int, by divisor: Int) -> Int {
        Int((Double(value) / Double(divisor)).rounded(.down))
    }

    private static func count(_ value: Int, _ unit: String) -> String {
        "\(Calculator.format(Double(value))) \(unit)\(value == 1 ? "" : "s")"
    }

    private static func label(_ date: Date, _ format: String, _ calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
