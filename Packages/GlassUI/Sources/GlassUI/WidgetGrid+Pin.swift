import AppKit

extension WidgetGrid {
    func dragOff(_ id: String?, at point: NSPoint) {
        guard let panel = unsafe window?.frame, !Self.railsFrame(beside: panel).contains(point),
            shown.first(where: { $0.id == id })?.isMedia == true
        else { return }
        onPinOff?()
    }
}
