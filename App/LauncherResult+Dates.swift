import GlassUI
import SearchKit

extension LauncherResult {
    static func dateSection(for query: String, in sources: Sources) -> ResultList.Section? {
        guard let answer = answer(for: query, in: sources) else { return nil }
        var item = item(for: answer)
        item.prefersSelection = true
        return ResultList.Section(title: answer.kind, items: [item])
    }
}
