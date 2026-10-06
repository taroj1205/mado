import AppKit

final class LyricsPaneNote: NSView {
    struct Message: Equatable {
        let symbol: String?
        let title: String
        let detail: String
    }

    static let settingsTitle = "Turn on in Settings"
    static let lookingUp = "Looking up lyrics"
    private static let symbolSize: CGFloat = 28
    private static let titleSize: CGFloat = 17
    private static let detailSize: CGFloat = 13
    private static let gap: CGFloat = 8
    private static let detailGap: CGFloat = 4
    private static let buttonHeight: CGFloat = 28
    private static let barHeight: CGFloat = 20
    private static let half: CGFloat = 0.5
    private static let barTop = (LyricsPaneLines.pitch - barHeight) * half
    private static let barWidths = (short: 0.58, medium: 0.78, long: 0.92)
    private static let bars = [barWidths.medium, barWidths.long, barWidths.short]

    let symbol = NSImageView()
    let title = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let settings = PillButton(settingsTitle, height: buttonHeight)
    let skeleton = bars.map { WidgetSkeleton(fraction: $0, height: barHeight) }
    var onSettings: (() -> Void)?
    private let message = NSStackView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        symbol.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .regular)
        symbol.contentTintColor = .secondaryLabelColor
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        settings.refusesFirstResponder = true
        settings.target = self
        settings.action = #selector(openSettings)
        message.orientation = .vertical
        message.alignment = .centerX
        message.spacing = Self.gap
        [symbol, title, detail, settings].forEach(message.addArrangedSubview)
        message.setCustomSpacing(Self.detailGap, after: title)
        message.translatesAutoresizingMaskIntoConstraints = false
        addSubview(message)
        NSLayoutConstraint.activate([
            message.centerXAnchor.constraint(equalTo: centerXAnchor),
            message.centerYAnchor.constraint(equalTo: centerYAnchor),
            message.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor),
            message.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
        var top = topAnchor
        for (index, bar) in skeleton.enumerated() {
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)
            let lead = index == 0 ? Self.barTop : Self.barTop + Self.barTop
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bar.widthAnchor.constraint(equalTo: widthAnchor, multiplier: bar.fraction),
                bar.topAnchor.constraint(equalTo: top, constant: lead),
            ])
            top = bar.bottomAnchor
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func message(for status: WidgetGrid.LyricsStatus) -> Message? {
        switch status {
        case .instrumental:
            Message(symbol: "music.note", title: "Instrumental", detail: "")

        case .missing:
            Message(
                symbol: "music.note.slash", title: "No lyrics for this track",
                detail: "Looked up by title, artist and length")

        case .off:
            Message(symbol: nil, title: "Lyrics are off", detail: "")

        case .synced, .plain, .loading:
            nil
        }
    }

    func show(_ status: WidgetGrid.LyricsStatus) {
        let shown = Self.message(for: status)
        let loading = status == .loading
        isHidden = shown == nil && !loading
        message.isHidden = shown == nil
        skeleton.forEach { $0.isHidden = !loading }
        symbol.image = shown?.symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        symbol.isHidden = symbol.image == nil
        title.stringValue = shown?.title ?? ""
        detail.stringValue = shown?.detail ?? ""
        detail.isHidden = detail.stringValue.isEmpty
        settings.isHidden = status != .off
        setAccessibilityElement(loading)
        setAccessibilityRole(loading ? .staticText : nil)
        setAccessibilityLabel(loading ? Self.lookingUp : nil)
    }

    @objc
    private func openSettings() {
        onSettings?()
    }
}
