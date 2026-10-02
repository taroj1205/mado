import AppCore
import AppKit
import GlassUI
import os
import SearchKit

extension CalculatorHistory {
    static let title = "Calculator History"
    static let symbol = "clock.arrow.circlepath"
    static let placeholder = "Type to filter calculations…"
    private static let key = "calculator_history"
    private static let commandID = "calculator.history"
    private static let entryPrefix = "calculator.history."
    private static let copyAnswer = "Copy Answer"
    private static let logger = Log.logger("CalculatorHistory")

    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        do {
            return try modules?.value(Self.self, for: key) ?? Self()
        } catch {
            logger.error("Calculator history failed to load: \(error, privacy: .public)")
            return Self()
        }
    }

    static func command(open: @escaping @MainActor @Sendable () -> Void) -> Command {
        Command(
            id: commandID, name: title, icon: symbol,
            actions: [CommandAction(id: "open", title: "Open \(title)", perform: open)],
            keywords: ["calculator", "maths", "math", "sums"])
    }

    static func opens(_ id: String) -> Bool {
        id == commandID
    }

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(entryPrefix)
    }

    private static func title(of day: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: now) { return "Today" }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        if let yesterday, calendar.isDate(day, inSameDayAs: yesterday) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    private static func item(_ entry: Entry) -> ResultList.Item {
        ResultList.Item(
            id: entryPrefix + entry.expression, title: "\(entry.expression) = \(entry.result)",
            subtitle: entry.kind, kind: entry.date.formatted(date: .omitted, time: .shortened),
            symbol: "equal", action: copyAnswer)
    }

    @MainActor
    private static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @MainActor
    mutating func remember(_ item: ResultList.Item, in modules: ModuleManager?) {
        guard let answer = item.answer else { return }
        record(expression: item.title, result: answer.value, kind: item.kind, at: .now)
        do {
            try modules?.setValue(self, for: Self.key)
        } catch {
            Self.logger.error("Saving calculator history failed: \(error, privacy: .public)")
        }
    }

    func sections(for query: String, now: Date, calendar: Calendar) -> [ResultList.Section] {
        let days = days(matching: query, calendar: calendar)
        guard !days.isEmpty else {
            let notice =
                entries.isEmpty
                ? ResultList.Notice(
                    title: "No calculations yet",
                    detail: "Answers you use from the calculator show up here.")
                : ResultList.Notice(
                    title:
                        "No calculations match “\(query.trimmingCharacters(in: .whitespaces))”",
                    detail: "Try part of the sum or its answer.")
            return [ResultList.Section(title: "", items: [], notice: notice)]
        }
        return days.map { day, calculations in
            ResultList.Section(
                title: Self.title(of: day, now: now, calendar: calendar),
                items: calculations.map(Self.item))
        }
    }

    func actions(for id: String) -> [CommandAction] {
        guard let entry = entries.first(where: { Self.entryPrefix + $0.expression == id }) else {
            return []
        }
        return [
            CommandAction(id: "copy", title: Self.copyAnswer) { Self.copy(entry.result) },
            CommandAction(id: "copy-expression", title: "Copy Expression") {
                Self.copy(entry.expression)
            },
        ]
    }
}
