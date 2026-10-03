import Carbon.HIToolbox
public import CoreGraphics
import InputKit

@MainActor
public struct SnippetTyping {
    public enum Outcome {
        case pass
        case expand(Snippet)
        case undo(TextInsertion.Inserted)
    }

    private static let shortcutFlags: CGEventFlags = [
        .maskCommand, .maskShift, .maskAlternate, .maskControl,
    ]

    public var settings = SnippetSettings() {
        didSet { keywords = settings.snippets.map(\.keyword) }
    }

    public private(set) var inputAfterMatch = false
    private var keywords: [String]
    private var buffer = KeywordBuffer()
    private var undoable: TextInsertion.Inserted?

    public init() {
        keywords = []
    }

    private static func isUndo(_ event: CGEvent) -> Bool {
        let key = KeyboardLayout.commandKeyCode(typing: "z") ?? CGKeyCode(kVK_ANSI_Z)
        return event.flags.intersection(shortcutFlags) == .maskCommand
            && event.getIntegerValueField(.keyboardEventKeycode) == Int64(key)
    }

    public mutating func handle(
        _ type: CGEventType, _ event: CGEvent, canExpand: Bool
    ) -> Outcome {
        guard !Keystrokes.isPosted(event) else { return .pass }
        inputAfterMatch = true
        guard type == .keyDown else {
            forget()
            return .pass
        }
        if let inserted = undoable, Self.isUndo(event) {
            undoable = nil
            return .undo(inserted)
        }
        undoable = nil
        guard canExpand, settings.expands else {
            buffer.reset()
            return .pass
        }
        guard let key = KeywordBuffer.key(for: event),
            let keyword = buffer.handle(key, keywords: keywords),
            let snippet = settings.snippet(withKeyword: keyword)
        else { return .pass }
        inputAfterMatch = false
        return .expand(snippet)
    }

    public mutating func expanded(_ inserted: TextInsertion.Inserted) {
        undoable = inserted.canUndo && !inserted.replaced.isEmpty ? inserted : nil
    }

    public mutating func forget() {
        buffer.reset()
        undoable = nil
    }
}
