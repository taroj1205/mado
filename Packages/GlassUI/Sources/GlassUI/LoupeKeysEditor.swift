public import AppKit

public final class LoupeKeysEditor: NSView {
    private static let boardHeight: CGFloat = 188
    private static let boardRadius: CGFloat = 16
    private static let keyGap: CGFloat = 10
    private static let noteGap: CGFloat = 8
    private static let noteSize: CGFloat = 11.5
    private static let prompt =
        "Click a key, then press the one you want. The arrows, Return and Esc always work."
    private static let fillAlpha = (dark: 0.18, light: 0.04)
    private static let edgeAlpha = (dark: 0.06, light: 0.08)
    private static let boardFill = SheetForm.adaptive(
        dark: .black.withAlphaComponent(fillAlpha.dark),
        light: .black.withAlphaComponent(fillAlpha.light))
    private static let boardEdge = SheetForm.adaptive(
        dark: .white.withAlphaComponent(edgeAlpha.dark),
        light: .black.withAlphaComponent(edgeAlpha.light))

    public var keys = LoupeKeys() {
        didSet {
            problem = nil
            render()
        }
    }
    public var onChange: ((LoupeKeys) -> Void)?

    let caps = Dictionary(
        uniqueKeysWithValues: LoupeKeys.Direction.allCases.map { ($0, LoupeKeyCap($0)) })
    let note = NSTextField(wrappingLabelWithString: prompt)
    private var problem: String?

    public init() {
        super.init(frame: .zero)
        for (direction, cap) in caps {
            cap.onKey = { [weak self] in self?.assign($0, to: direction) }
        }
        note.font = .systemFont(ofSize: Self.noteSize)
        let stack = NSStackView(views: [board(), note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.noteGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.arrangedSubviews[0].widthAnchor.constraint(equalTo: stack.widthAnchor),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        render()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func board() -> NSView {
        let cluster = NSStackView(views: [row([.top]), row([.left, .bottom, .right])])
        cluster.orientation = .vertical
        cluster.spacing = Self.keyGap
        cluster.translatesAutoresizingMaskIntoConstraints = false
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = Self.boardRadius
        box.fillColor = Self.boardFill
        box.borderColor = Self.boardEdge
        box.contentViewMargins = .zero
        box.addSubview(cluster)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: Self.boardHeight),
            cluster.centerXAnchor.constraint(equalTo: box.centerXAnchor),
            cluster.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }

    private func row(_ directions: [LoupeKeys.Direction]) -> NSStackView {
        let row = NSStackView(views: directions.compactMap { caps[$0] })
        row.spacing = Self.keyGap
        return row
    }

    private func assign(_ keyCode: Int, to direction: LoupeKeys.Direction) {
        var changed = keys
        if let refusal = changed.assign(keyCode, to: direction) {
            problem = refusal
            render()
            return
        }
        keys = changed
        onChange?(changed)
    }

    private func render() {
        for (direction, cap) in caps {
            cap.letter = keys.label(of: direction)
        }
        note.stringValue = problem ?? Self.prompt
        note.textColor = problem == nil ? .secondaryLabelColor : .systemOrange
    }
}
