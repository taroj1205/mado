import AppKit

final class EventCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("event")
    private static let leadingInset: CGFloat = 10
    private static let trailingInset: CGFloat = 12
    private static let gap: CGFloat = 12
    private static let timeWidth: CGFloat = 62
    private static let timeSize: CGFloat = 12.5
    private static let barWidth: CGFloat = 4
    private static let barHeight: CGFloat = 26
    private static let barRadius: CGFloat = 2
    private static let titleSize: CGFloat = 14
    private static let subtitleSize: CGFloat = 12
    private static let symbolSize: CGFloat = 13
    private static let keyGap: CGFloat = 3
    private static let dimmedAlpha: CGFloat = 0.45

    let time = NSTextField(labelWithString: "")
    let bar = NSBox()
    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let video = NSImageView()
    let shortcut = NSStackView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        time.font = .monospacedDigitSystemFont(ofSize: Self.timeSize, weight: .regular)
        time.textColor = .secondaryLabelColor
        bar.boxType = .custom
        bar.borderWidth = 0
        bar.cornerRadius = Self.barRadius
        title.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        subtitle.font = .systemFont(ofSize: Self.subtitleSize)
        subtitle.textColor = .secondaryLabelColor
        for label in [time, title, subtitle] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        video.image = NSImage(systemSymbolName: "video", accessibilityDescription: nil)
        video.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .regular)
        video.contentTintColor = .secondaryLabelColor
        shortcut.spacing = Self.keyGap
        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 0
        let accessory = NSStackView(views: [video, shortcut])
        accessory.setHuggingPriority(.defaultHigh, for: .horizontal)
        setAccessibilityChildren([])
        layout(time, bar, text, accessory)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ item: ResultList.Item, _ event: ResultList.Event) {
        time.stringValue = event.time
        bar.fillColor = event.colour
        title.stringValue = item.title
        subtitle.stringValue = item.subtitle
        subtitle.isHidden = item.subtitle.isEmpty
        shortcut.setViews(item.shortcut.map(FloatingCapsule.keycap), in: .leading)
        shortcut.isHidden = item.shortcut.isEmpty
        video.isHidden = !event.hasMeeting || !item.shortcut.isEmpty
        alphaValue = item.isDimmed ? Self.dimmedAlpha : 1
        setAccessibilityLabel(
            [event.time, item.title, item.subtitle].filter { !$0.isEmpty }.joined(separator: ", "))
    }

    private func layout(_ time: NSView, _ bar: NSView, _ text: NSView, _ accessory: NSView) {
        for view in [time, bar, text, accessory] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
            view.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            time.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.leadingInset),
            time.widthAnchor.constraint(equalToConstant: Self.timeWidth),
            bar.leadingAnchor.constraint(equalTo: time.trailingAnchor, constant: Self.gap),
            bar.widthAnchor.constraint(equalToConstant: Self.barWidth),
            bar.heightAnchor.constraint(equalToConstant: Self.barHeight),
            text.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: Self.gap),
            accessory.leadingAnchor.constraint(
                greaterThanOrEqualTo: text.trailingAnchor, constant: Self.gap),
            accessory.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.trailingInset),
        ])
    }
}
