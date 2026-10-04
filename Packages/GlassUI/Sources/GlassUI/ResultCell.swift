import AppCore
import AppKit

final class ResultCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("result")
    static let tileSize: CGFloat = 26
    private static let tileRadius: CGFloat = 8
    private static let tileBorder: CGFloat = 0.5
    private static let tileBorderAlpha: CGFloat = 0.18
    private static let symbolSize: CGFloat = 12
    private static let leadingInset: CGFloat = 10
    private static let trailingInset: CGFloat = 12
    private static let gap: CGFloat = 12
    private static let titleSize: CGFloat = 14
    private static let subtitleSize: CGFloat = 13
    private static let kindSize: CGFloat = 12
    private static let keyGap: CGFloat = 3
    private static let dimmedAlpha: CGFloat = 0.45

    let tile = NSBox()
    let symbol = NSImageView()
    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let kind = NSTextField(labelWithString: "")
    let shortcut = NSStackView()
    let hotkey = NSStackView()
    private let accessory = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        tile.boxType = .custom
        tile.fillColor = ResultRowView.fill
        tile.borderColor = .black.withAlphaComponent(Self.tileBorderAlpha)
        tile.borderWidth = Self.tileBorder
        tile.cornerRadius = Self.tileRadius
        tile.contentViewMargins = .zero
        symbol.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .medium)
        tile.contentView = symbol
        title.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultHigh - 1, for: .horizontal)
        subtitle.font = .systemFont(ofSize: Self.subtitleSize)
        subtitle.textColor = .secondaryLabelColor
        subtitle.lineBreakMode = .byTruncatingTail
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitle.setContentHuggingPriority(.defaultLow, for: .horizontal)
        kind.font = .systemFont(ofSize: Self.kindSize)
        kind.textColor = .secondaryLabelColor
        for keys in [hotkey, shortcut] {
            keys.spacing = Self.keyGap
            keys.setHuggingPriority(.defaultHigh, for: .horizontal)
        }
        accessory.setViews([kind, hotkey, shortcut], in: .leading)
        accessory.spacing = Self.gap
        accessory.setHuggingPriority(.defaultHigh, for: .horizontal)
        setAccessibilityChildren([])
        layout(tile, title, subtitle, accessory)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ item: ResultList.Item) {
        symbol.image =
            item.icon ?? NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        symbol.contentTintColor = item.tint == nil ? .labelColor : .white
        tile.fillColor = item.icon == nil ? item.tint ?? ResultRowView.fill : .clear
        tile.borderWidth = item.icon == nil ? Self.tileBorder : 0
        title.stringValue = item.title
        subtitle.stringValue = item.subtitle
        alphaValue = item.isDimmed ? Self.dimmedAlpha : 1
        kind.stringValue = item.kind
        kind.isHidden = item.kind.isEmpty || item.hotkey != nil
        let hotkeyKeys = item.hotkey.map { HotKeyLabel.keycaps(.shortcut($0)) } ?? []
        hotkey.setViews(hotkeyKeys.map(FloatingCapsule.keycap), in: .leading)
        hotkey.isHidden = hotkeyKeys.isEmpty
        shortcut.setViews(item.shortcut.map(FloatingCapsule.keycap), in: .leading)
        shortcut.isHidden = item.shortcut.isEmpty
        let detail = item.hotkey.map { "hotkey \(HotKeyLabel.spoken($0))" } ?? item.kind
        setAccessibilityLabel(
            [item.title, detail, item.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    private func layout(_ views: NSView...) {
        for view in views {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            tile.widthAnchor.constraint(equalToConstant: Self.tileSize),
            tile.heightAnchor.constraint(equalToConstant: Self.tileSize),
            tile.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.leadingInset),
            title.leadingAnchor.constraint(equalTo: tile.trailingAnchor, constant: Self.gap),
            subtitle.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: Self.gap),
            accessory.leadingAnchor.constraint(
                equalTo: subtitle.trailingAnchor, constant: Self.gap),
            accessory.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.trailingInset),
        ])
    }
}
