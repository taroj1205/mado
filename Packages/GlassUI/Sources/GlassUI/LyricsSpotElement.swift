import AppKit

final class LyricsSpotElement: NSAccessibilityElement {
    let spot: LyricsSpot
    var onPress: ((LyricsSpot) -> Void)?

    init(_ spot: LyricsSpot, frame: CGRect, parent: NSView) {
        self.spot = spot
        super.init()
        setAccessibilityRole(.radioButton)
        setAccessibilityLabel(spot.title)
        setAccessibilityHelp(spot.detail)
        setAccessibilityValue(0)
        setAccessibilityParent(parent)
        setAccessibilityFrameInParentSpace(frame)
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?(spot)
        return true
    }
}
