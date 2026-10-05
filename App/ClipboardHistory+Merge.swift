import AppCore
import AppKit
import ClipboardKit
import GlassUI

extension ClipboardHistory {
    private static func note(_ originals: String, saving kind: String) -> String {
        let kept = "\(originals) in history unchanged; the \(kind) text is saved as a new item."
        return "Edits apply to what gets pasted. \(kept)"
    }

    private static func titles(joins: Bool) -> (paste: String, copy: String) {
        joins ? ("Paste Merged", "Copy Merged") : ("Paste Edited", "Copy Edited")
    }

    private static func draftActions(
        _ draft: (merge: LauncherView.Merge, text: String), pastingInto target: PasteTarget?
    ) -> [(action: CommandAction, keys: [String])] {
        let titles = titles(joins: draft.merge.joins)
        let source = Bundle.main.bundleIdentifier
        let text = { () throws -> String in
            guard !draft.text.isEmpty else { throw PasteTarget.Failure.notWritten }
            return draft.text
        }
        let copy = CommandAction(id: "copy.draft", title: titles.copy) {
            try Clip.copyText(text(), source: source)
        }
        guard let target else { return [(copy, LauncherView.Action.secondaryKeys)] }
        let paste = CommandAction(id: "paste.draft", title: titles.paste) {
            try await target.paste(Clip.savedTextItems(text(), source: source))
        }
        return [
            (paste, LauncherView.Action.primaryKeys), (copy, LauncherView.Action.secondaryKeys),
        ]
    }

    func merge(for ids: [String], pastingInto target: PasteTarget?) -> LauncherView.Merge? {
        let texts = ids.compactMap { entries[$0]?.plainText }
        guard texts.count > 1 else { return nil }
        return LauncherView.Merge(
            title: "Merge \(texts.count) items", texts: texts, joins: true,
            note: Self.note("The \(texts.count) originals stay", saving: "merged"),
            action: target == nil ? "" : Self.titles(joins: true).paste)
    }

    func edit(_ item: ResultList.Item, pastingInto target: PasteTarget?) -> LauncherView.Merge? {
        guard let text = entries[item.id]?.plainText else { return nil }
        return LauncherView.Merge(
            title: "Edit item", texts: [text], joins: false,
            note: Self.note("The original stays", saving: "edited"),
            action: target == nil ? "" : Self.titles(joins: false).paste, item: item.id)
    }

    func actions(
        for id: String, pastingInto target: PasteTarget?,
        draft: (merge: LauncherView.Merge, text: String)?
    ) -> [(action: CommandAction, keys: [String])] {
        if let draft { return Self.draftActions(draft, pastingInto: target) }
        return actions(for: id, pastingInto: target)
    }
}
