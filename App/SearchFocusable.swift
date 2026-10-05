import AppKit
import GlassUI

@MainActor
protocol SearchFocusable: NSView {
    var takesSearchFocus: Bool { get set }
}

extension SettingsSwitch: SearchFocusable {}

extension SettingsPopUp: SearchFocusable {}

extension SettingsButton: SearchFocusable {}

extension HotKeyButton: SearchFocusable {}

extension NSView {
    func firstVisible<View>(_ type: View.Type) -> View? {
        guard !isHidden else { return nil }
        if let match = self as? View {
            return match
        }
        return subviews.lazy.compactMap { $0.firstVisible(type) }.first
    }
}
