import AppKit

@MainActor
protocol SearchFocusable: NSView {
    var takesSearchFocus: Bool { get set }
}

extension SettingsSwitch: SearchFocusable {}

extension SettingsPopUp: SearchFocusable {}

extension SettingsButton: SearchFocusable {}
