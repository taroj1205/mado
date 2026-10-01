import AppKit
import GlassUI

final class LauncherView: NSView {
    private static let searchBarHeight: CGFloat = 60
    private static let searchInset: CGFloat = 20
    private static let searchFontSize: CGFloat = 20
    private static let searchIconGap: CGFloat = 12
    private static let resultsInset: CGFloat = 8

    let field = NSTextField()
    let results = ResultList()

    override init(frame: NSRect) {
        super.init(frame: frame)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: Self.searchFontSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        field.placeholderString = "Search apps and commands…"
        field.font = .systemFont(ofSize: Self.searchFontSize)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        let separator = NSBox()
        separator.boxType = .separator
        let bar = NSLayoutGuide()
        addLayoutGuide(bar)
        for view in [icon, field, separator, results] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.searchBarHeight),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.searchInset),
            icon.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            field.leadingAnchor.constraint(
                equalTo: icon.trailingAnchor, constant: Self.searchIconGap),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.searchInset),
            field.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: bar.bottomAnchor),
            results.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.resultsInset),
            results.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.resultsInset),
            results.topAnchor.constraint(equalTo: separator.bottomAnchor),
            results.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }
}
