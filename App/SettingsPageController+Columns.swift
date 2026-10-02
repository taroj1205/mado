import AppKit

extension SettingsPageController {
    private static let columnGap: CGFloat = 12

    static func columns(_ boxes: [NSView]) -> NSView {
        guard boxes.count > 1 else { return boxes.first ?? NSView() }
        let columns = NSStackView(views: boxes)
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = columnGap
        return columns
    }
}
