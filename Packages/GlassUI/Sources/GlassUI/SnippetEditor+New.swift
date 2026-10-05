import AppKit

extension SnippetEditor {
    public func beginNew(with text: String) {
        startNew()
        textView.string = text
        highlightTokens()
    }
}
