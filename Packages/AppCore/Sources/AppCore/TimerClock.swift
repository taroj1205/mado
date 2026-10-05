public import Foundation

public enum TimerClock {
    private static let secondsPerMinute = 60
    private static let minutesPerHour = 60
    private static let digits = 10

    public static func text(_ seconds: TimeInterval, roundingUp: Bool) -> String {
        let whole = Int(roundingUp ? seconds.rounded(.up) : seconds.rounded(.down))
        let (minutes, second) = max(0, whole).quotientAndRemainder(dividingBy: secondsPerMinute)
        let (hours, minute) = minutes.quotientAndRemainder(dividingBy: minutesPerHour)
        let pair = { (value: Int) in value < digits ? "0\(value)" : "\(value)" }
        return hours > 0 ? "\(hours):\(pair(minute)):\(pair(second))" : "\(minute):\(pair(second))"
    }

    public static func length(_ seconds: TimeInterval) -> String {
        let (minutes, rest) = Int(seconds.rounded()).quotientAndRemainder(
            dividingBy: secondsPerMinute)
        let (hours, minute) = minutes.quotientAndRemainder(dividingBy: minutesPerHour)
        let parts = [(hours, "h"), (minute, "min"), (rest, "s")]
            .filter { amount, _ in amount > 0 }
            .map { amount, unit in "\(amount) \(unit)" }
        return parts.isEmpty ? "0 s" : parts.joined(separator: " ")
    }
}
