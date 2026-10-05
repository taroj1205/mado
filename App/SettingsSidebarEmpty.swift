import AppKit

final class SettingsSidebarEmpty: NSStackView {
    private static let iconSize: CGFloat = 24
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 11

    private let detail = NSTextField(wrappingLabelWithString: "")

    init() {
        super.init(frame: .zero)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .light)
        icon.contentTintColor = .secondaryLabelColor
        let title = NSTextField(labelWithString: "No Results")
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        detail.alignment = .center
        setViews([icon, title, detail], in: .center)
        orientation = .vertical
        alignment = .centerX
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(query: String?) {
        isHidden = query == nil
        detail.stringValue = query.map { "Nothing in Settings matches “\($0)”." } ?? ""
        setAccessibilityLabel(isHidden ? nil : "No Results. \(detail.stringValue)")
    }
}
