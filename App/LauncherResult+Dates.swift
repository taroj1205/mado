import GlassUI
import SearchKit

extension LauncherResult {
    static func dateSection(for query: String, in sources: Sources) -> ResultList.Section? {
        guard let answer = answer(for: query, in: sources) else { return nil }
        var item = ResultList.Item(
            id: answerID, title: answer.result,
            subtitle: "\(answer.expression) · \(answer.resultDetail)", kind: answer.kind,
            symbol: answerSymbol, action: "Copy Answer")
        item.prefersSelection = true
        return ResultList.Section(title: answer.kind, items: [item])
    }
}
