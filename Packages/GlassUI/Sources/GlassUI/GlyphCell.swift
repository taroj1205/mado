import AppKit

final class GlyphCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("glyph")
    private static let glyphSize: CGFloat = 16
    static let thumbnailSize: CGFloat = 24
    private static let symbolSize: CGFloat = 13
    private static let inset: CGFloat = 10
    private static let gap: CGFloat = 10
    private static let titleSize: CGFloat = 13

    let glyph = NSImageView()
    let title = NSTextField(labelWithString: "")
    let thumbnail = ThumbnailView()
    var thumbnails = Thumbnails.shared
    private(set) var loading: Task<Void, Never>?
    private var imageURL: URL?
    private var request: Thumbnails.Request?

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        glyph.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .medium)
        title.font = .systemFont(ofSize: Self.titleSize)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setAccessibilityChildren([])
        thumbnail.isHidden = true
        for view in [glyph, title, thumbnail] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            glyph.widthAnchor.constraint(equalToConstant: Self.glyphSize),
            glyph.heightAnchor.constraint(equalToConstant: Self.glyphSize),
            glyph.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.inset),
            thumbnail.widthAnchor.constraint(equalToConstant: Self.thumbnailSize),
            thumbnail.heightAnchor.constraint(equalToConstant: Self.thumbnailSize),
            thumbnail.centerXAnchor.constraint(equalTo: glyph.centerXAnchor),
            title.leadingAnchor.constraint(equalTo: glyph.trailingAnchor, constant: Self.gap),
            title.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.inset),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ item: ResultList.Item) {
        glyph.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
        glyph.contentTintColor = item.tint ?? .secondaryLabelColor
        title.stringValue = item.title
        let spoken = item.kind == item.title ? [item.title] : [item.title, item.kind]
        setAccessibilityLabel(spoken.filter { !$0.isEmpty }.joined(separator: ", "))
        imageURL = item.thumbnail
        loadThumbnail()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        loadThumbnail()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        loadThumbnail()
    }

    private func loadThumbnail() {
        let next: Thumbnails.Request? =
            if let url = imageURL, let scale = unsafe window?.backingScaleFactor {
                .init(url: url, side: Int((Self.thumbnailSize * scale).rounded(.up)))
            } else {
                nil
            }
        guard next != request else { return }
        request = next
        loading = nil
        let cached = next.flatMap(thumbnails.cached)
        display(cached)
        guard let next, cached == nil else { return }
        loading = Task { [weak self, thumbnails] in
            let image = await thumbnails.load(next)
            guard let self, request == next else { return }
            display(image)
        }
    }

    private func display(_ image: CGImage?) {
        thumbnail.image = image
        thumbnail.isHidden = image == nil
        glyph.isHidden = image != nil
    }
}
