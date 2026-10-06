import AppKit

final class LyricsPaneRow: NSAccessibilityElement {
    var onPress: (() -> Void)?

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return onPress != nil
    }
}
