import AppKit

final class LyricsPaneHints: NSView {
    struct Hint: Equatable {
        let keys: String
        let title: String
    }

    static let height: CGFloat = 36
    static let synced = [
        Hint(keys: "↑↓", title: "Browse"), Hint(keys: "↵", title: "Play from this line"),
        Hint(keys: "⌘C", title: "Copy line"), close,
    ]
    static let plain = [
        Hint(keys: "↑↓", title: "Scroll"), Hint(keys: "⌘C", title: "Copy lyrics"), close,
    ]
    static let close = Hint(keys: "Esc", title: "Close")
    private static let fontSize: CGFloat = 12
    private static let hintGap: CGFloat = 14
    private static let keyGap: CGFloat = 6

    private(set) var shown: [Hint] = []
    private let stack = NSStackView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let line = NSBox()
        line.boxType = .separator
        stack.spacing = Self.hintGap
        for view in [line, stack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func hints(for status: WidgetGrid.LyricsStatus) -> [Hint] {
        switch status {
        case .synced: synced
        case .plain: plain
        case .instrumental, .missing, .loading, .off: [close]
        }
    }

    func show(_ hints: [Hint]) {
        guard hints != shown else { return }
        shown = hints
        stack.setViews(
            hints.map { hint in
                let label = NSTextField(labelWithString: hint.title)
                label.font = .systemFont(ofSize: Self.fontSize)
                label.textColor = .secondaryLabelColor
                let pair = NSStackView(views: [FloatingCapsule.keycap(hint.keys), label])
                pair.spacing = Self.keyGap
                return pair
            }, in: .leading)
    }
}
