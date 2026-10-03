public import AppCore
public import AppKit

public final class ModifierKeycaps: NSStackView {
    public init(_ modifiers: Shortcut.Modifiers) {
        super.init(frame: .zero)
        setViews(HotKeyButton.keycaps(HotKeyLabel.symbols(modifiers)), in: .leading)
        spacing = HotKeyButton.keyGap
        setHuggingPriority(.defaultHigh, for: .horizontal)
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityValue(HotKeyLabel.spoken(modifiers))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
