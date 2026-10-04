import AppKit

final class KeywordField: NSTextField {
    private final class PlainCell: NSTextFieldCell {
        override func fieldEditor(for controlView: NSView) -> NSTextView? {
            (controlView as? KeywordField)?.editor
        }
    }

    private let editor = NSTextView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        editor.isFieldEditor = true
        editor.turnOffSubstitutions()
        let plain = PlainCell(textCell: "")
        plain.isEditable = true
        cell = plain
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}

extension NSTextView {
    func turnOffSubstitutions() {
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
    }
}
