import AppCore
import ClipboardKit
import Foundation
import GlassUI
import os

extension ClipboardHistory {
    private static func bringToTop(_ entry: ClipboardStore.Entry, in store: ClipboardStore) async {
        do {
            try await store.bringToTop(id: entry.id, at: .now)
        } catch {
            Self.logger.error("Moving a reused entry up failed: \(error, privacy: .public)")
        }
    }

    func actions(
        for id: String, pastingInto target: PasteTarget?
    ) -> [(action: CommandAction, keys: [String])] {
        guard let entry = entries[id], let store else { return [] }
        let copy = CommandAction(id: "copy", title: "Copy to Clipboard") {
            let data = try await store.data(for: entry.id)
            try entry.copy(data: data)
            await Self.bringToTop(entry, in: store)
        }
        guard let target else { return [(copy, LauncherView.Action.secondaryKeys)] }
        let paste = CommandAction(id: "paste", title: target.title) {
            try await entry.paste(data: store.data(for: entry.id), into: target)
            await Self.bringToTop(entry, in: store)
        }
        let plain = CommandAction(id: "paste.plain", title: "Paste as Plain Text") {
            try await entry.pastePlainText(into: target)
            await Self.bringToTop(entry, in: store)
        }
        return [(paste, LauncherView.Action.primaryKeys)]
            + (entry.plainText == nil ? [] : [(plain, LauncherView.Action.alternateKeys)])
            + [(copy, LauncherView.Action.secondaryKeys)]
    }
}
