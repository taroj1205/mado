public import AppKit

final class DetailPane: NSView {
    static let listWidth: CGFloat = 296
    private static let top: CGFloat = 12
    private static let side: CGFloat = 16
    private static let bottom: CGFloat = 62
    private static let gap: CGFloat = 14
    private static let boxRadius: CGFloat = 12
    private static let boxInset: CGFloat = 16
    private static let textSize: CGFloat = 13
    private static let lineHeight: CGFloat = 1.6
    private static let textLimit = 2_000
    private static let headerSize: CGFloat = 12
    private static let headerBottom: CGFloat = 6
    private static let rowHeight: CGFloat = 30
    private static let rowInset: CGFloat = 2
    private static let detailSize: CGFloat = 12.5
    private static let fillAlpha = (dark: 0.22, light: 0.04)
    private static let edgeAlpha: CGFloat = 0.06
    private static let fill = NSColor(name: nil) { appearance in
        .black.withAlphaComponent(isDark(appearance) ? fillAlpha.dark : fillAlpha.light)
    }
    private static let edge = NSColor(name: nil) { appearance in
        (isDark(appearance) ? NSColor.white : .black).withAlphaComponent(edgeAlpha)
    }

    let box = NSBox()
    let text = NSTextField(wrappingLabelWithString: "")
    let image = NSImageView()
    let info = NSStackView()
    private let header = DetailPane.makeHeader()

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        let divider = NSBox()
        divider.boxType = .separator
        let content = NSView()
        content.clipsToBounds = true
        box.boxType = .custom
        box.cornerRadius = Self.boxRadius
        box.borderWidth = 1
        box.fillColor = Self.fill
        box.borderColor = Self.edge
        box.contentViewMargins = NSSize(width: Self.boxInset, height: Self.boxInset)
        box.contentView = content
        text.isSelectable = false
        image.imageScaling = .scaleProportionallyDown
        image.setAccessibilityLabel("Image preview")
        for view in [text, image] {
            view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            view.setContentHuggingPriority(.defaultLow, for: .vertical)
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: content.topAnchor),
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: content.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            ])
        }
        info.orientation = .vertical
        info.alignment = .leading
        info.spacing = 0
        info.setHuggingPriority(.required, for: .vertical)
        layout(divider)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func isDark(_ appearance: NSAppearance) -> Bool {
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }

    private static func makeHeader() -> NSView {
        let view = NSView()
        let title = NSTextField(labelWithString: "Information")
        title.font = .systemFont(ofSize: headerSize, weight: .semibold)
        title.textColor = .secondaryLabelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: rowInset),
            title.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            title.topAnchor.constraint(equalTo: view.topAnchor),
            title.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        return view
    }

    private static func label(_ string: String, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = .systemFont(ofSize: detailSize)
        label.textColor = color
        label.lineBreakMode = .byTruncatingMiddle
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func row(_ name: String, _ value: String) -> NSView {
        let row = NSView()
        let line = NSBox()
        line.boxType = .separator
        let key = label(name, color: .secondaryLabelColor)
        key.setContentCompressionResistancePriority(.required, for: .horizontal)
        let shown = label(value, color: .labelColor)
        shown.alignment = .right
        shown.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        for view in [line, key, shown] {
            view.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(view)
        }
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: rowHeight),
            line.topAnchor.constraint(equalTo: row.topAnchor),
            line.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            key.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: rowInset),
            key.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            shown.leadingAnchor.constraint(
                greaterThanOrEqualTo: key.trailingAnchor, constant: rowInset),
            shown.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -rowInset),
            shown.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        row.setAccessibilityElement(true)
        row.setAccessibilityRole(.staticText)
        row.setAccessibilityLabel("\(name), \(value)")
        return row
    }

    func show(_ preview: LauncherView.Preview?) {
        box.isHidden = preview == nil
        info.isHidden = preview == nil
        guard let preview else { return }
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = Self.textSize * Self.lineHeight
        style.maximumLineHeight = style.minimumLineHeight
        text.attributedStringValue = NSAttributedString(
            string: String(preview.text.prefix(Self.textLimit)),
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: Self.textSize, weight: .regular),
                .foregroundColor: NSColor.labelColor, .paragraphStyle: style,
            ])
        text.isHidden = preview.image != nil
        image.image = preview.image
        image.isHidden = preview.image == nil
        let rows = preview.details.map { Self.row($0.name, $0.value) }
        info.setViews([header] + rows, in: .top)
        info.setCustomSpacing(Self.headerBottom, after: header)
        for row in rows {
            row.widthAnchor.constraint(equalTo: info.widthAnchor).isActive = true
        }
    }

    private func layout(_ divider: NSView) {
        for view in [divider, box, info] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            box.topAnchor.constraint(equalTo: topAnchor, constant: Self.top),
            box.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: Self.side),
            box.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            info.topAnchor.constraint(equalTo: box.bottomAnchor, constant: Self.gap),
            info.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            info.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            info.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.bottom),
        ])
    }
}

extension LauncherView {
    public struct Preview {
        public let text: String
        public let image: NSImage?
        public let details: [(name: String, value: String)]

        public init(text: String, image: NSImage?, details: [(name: String, value: String)]) {
            self.text = text
            self.image = image
            self.details = details
        }
    }
}
