public import AppKit
import Carbon.HIToolbox
import os

@MainActor
public struct TextInsertion {
    public enum Failure: Error {
        case clipboardChanged
    }

    public struct Inserted {
        let length: Int
        let caretBack: Int
        let replaced: String
        let saved: [NSPasteboardItem]
        let changeCount: Int
        let text: LazyText

        var canUndo: Bool { length <= TextInsertion.keyLimit }
    }

    final class LazyText: NSObject, NSPasteboardItemDataProvider, Sendable {
        let text: String
        private let read = OSAllocatedUnfairLock(initialState: false)

        var wasRead: Bool { read.withLock { $0 } }

        init(_ text: String) {
            self.text = text
        }

        func pasteboard(
            _: NSPasteboard?, item: NSPasteboardItem,
            provideDataForType type: NSPasteboard.PasteboardType
        ) {
            item.setString(text, forType: type)
            read.withLock { $0 = true }
        }
    }

    private static var restoringUntil: [NSPasteboard.Name: ContinuousClock.Instant] = [:]

    nonisolated static let keyLimit = 1_000
    private static let restoreMilliseconds = 500
    private static let pasteSeconds = 5
    private static let pollMilliseconds = 50
    private static let restoreSlackSeconds = 10
    public static let standard = Self(
        pasteboard: .general, restoreDelay: .milliseconds(restoreMilliseconds),
        pasteTimeout: .seconds(pasteSeconds), post: Keystrokes.post)

    let pasteboard: NSPasteboard
    let restoreDelay: Duration
    let pasteTimeout: Duration
    let post: @MainActor ([CGEvent]) -> Void

    private static func copy(_ item: NSPasteboardItem) -> NSPasteboardItem {
        let copy = NSPasteboardItem()
        for type in item.types {
            if let data = item.data(forType: type) {
                copy.setData(data, forType: type)
            }
        }
        return copy
    }

    private static func transient(_ item: NSPasteboardItem) -> NSPasteboardItem {
        item.setData(Data(), forType: PasteboardWatch.transientType)
        return item
    }

    public func replace(
        _ typed: String, with expansion: SnippetTemplate.Expansion,
        if isCurrent: @MainActor () async -> Bool
    ) async throws -> Inserted? {
        try await waitForRestore()
        let changeCount = pasteboard.changeCount
        let saved = savedItems()
        guard await isCurrent() else { return nil }
        return try put(expansion, replacing: typed, saved: saved, changeCount: changeCount)
    }

    public func paste(_ text: String) async throws {
        try await waitForRestore()
        let plain = SnippetTemplate.Expansion(text: text, caretBack: 0, fieldRanges: [])
        let changeCount = pasteboard.changeCount
        let inserted = try put(
            plain, replacing: "", saved: savedItems(), changeCount: changeCount)
        Task { await restore(inserted) }
    }

    func waitForRestore() async throws {
        while let until = Self.restoringUntil[pasteboard.name], ContinuousClock.now < until {
            try await Task.sleep(for: .milliseconds(Self.pollMilliseconds))
        }
    }

    private func savedItems() -> [NSPasteboardItem] {
        pasteboard.pasteboardItems?.map(Self.copy) ?? []
    }

    private func put(
        _ expansion: SnippetTemplate.Expansion, replacing typed: String,
        saved: [NSPasteboardItem], changeCount: Int
    ) throws -> Inserted {
        let delete = try Keystrokes.press(CGKeyCode(kVK_Delete), flags: [], times: typed.count)
        let caretBack = expansion.caretBack <= Self.keyLimit ? expansion.caretBack : 0
        let back = try Keystrokes.press(
            CGKeyCode(kVK_LeftArrow), flags: Keystrokes.arrowFlags, times: caretBack)
        let paste = try PasteTarget.commandV()
        let text = LazyText(expansion.text)
        let item = NSPasteboardItem()
        guard item.setDataProvider(text, forTypes: [.string]) else {
            throw PasteTarget.Failure.notWritten
        }
        guard pasteboard.changeCount == changeCount else { throw Failure.clipboardChanged }
        do {
            try PasteTarget.write([Self.transient(item)], to: pasteboard)
        } catch {
            put(back: saved)
            throw error
        }
        let written = pasteboard.changeCount
        let allowed = pasteTimeout + restoreDelay + .seconds(Self.restoreSlackSeconds)
        Self.restoringUntil[pasteboard.name] = .now + allowed
        post(delete + paste + back)
        return Inserted(
            length: expansion.text.count, caretBack: caretBack, replaced: typed,
            saved: saved, changeCount: written, text: text)
    }

    public func restore(_ inserted: Inserted) async {
        defer { Self.restoringUntil[pasteboard.name] = nil }
        let deadline = ContinuousClock.now + pasteTimeout
        while !inserted.text.wasRead, ContinuousClock.now < deadline {
            do {
                try await Task.sleep(for: .milliseconds(Self.pollMilliseconds))
            } catch {
                break
            }
        }
        try? await Task.sleep(for: restoreDelay)
        guard pasteboard.changeCount == inserted.changeCount else { return }
        put(back: inserted.saved)
    }

    private func put(back saved: [NSPasteboardItem]) {
        pasteboard.clearContents()
        guard let first = saved.first else { return }
        pasteboard.writeObjects([Self.transient(first)] + saved.dropFirst())
    }

    public func undo(_ inserted: Inserted) throws {
        let forward = try Keystrokes.press(
            CGKeyCode(kVK_RightArrow), flags: Keystrokes.arrowFlags, times: inserted.caretBack)
        let delete = try Keystrokes.press(
            CGKeyCode(kVK_Delete), flags: [], times: inserted.length)
        let retype = inserted.replaced.isEmpty ? [] : try Keystrokes.typing(inserted.replaced)
        post(forward + delete + retype)
    }
}
