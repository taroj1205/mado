import AppKit

final class MergePane: NSView, NSTextViewDelegate {
    struct Separator: Equatable {
        let title: String
        let value: String
    }

    static let separators = [
        Separator(title: "New line", value: "\n"), Separator(title: "Blank line", value: "\n\n"),
        Separator(title: "Space", value: " "), Separator(title: "Comma", value: ", "),
    ]
    private static let top: CGFloat = 14
    private static let side: CGFloat = 18
    private static let gap: CGFloat = 10
    private static let titleGap: CGFloat = 12
    private static let titleSize: CGFloat = 14
    private static let joinSize: CGFloat = 12.5
    private static let joinGap: CGFloat = 8
    private static let textSize: CGFloat = 13.5
    private static let lineHeight: CGFloat = 1.5
    private static let textInset: CGFloat = 12
    private static let boxRadius: CGFloat = 10
    private static let boxHeights: ClosedRange<CGFloat> = 92...220
    private static let noteSize: CGFloat = 12
    private static let buttonHeight: CGFloat = 26
    private static let buttonGap: CGFloat = 8
    private static let focusAlpha: CGFloat = 0.55
    private static let focusWidth: CGFloat = 1.5
    private static let fillAlpha = (dark: 0.22, light: 0.04)
    private static let fill = SheetForm.adaptive(
        dark: .black.withAlphaComponent(fillAlpha.dark),
        light: .black.withAlphaComponent(fillAlpha.light))

    let title = NSTextField(labelWithString: "")
    let editor = MergeTextView()
    let note = NSTextField(wrappingLabelWithString: "")
    let joinMenu = NSPopUpButton(frame: .zero, pullsDown: false)
    let strip = PillButton(
        "Strip formatting", height: MergePane.buttonHeight, symbol: "text.alignleft",
        fill: FloatingCapsule.keycapFill, text: .labelColor)
    let snippet = PillButton(
        "Save as Snippet…", height: MergePane.buttonHeight, symbol: "plus",
        fill: FloatingCapsule.keycapFill, text: .labelColor)
    var onEscape: (() -> Void)?
    var onFocus: ((Bool) -> Void)?
    var onSnippet: ((String) -> Void)?
    private(set) var merge: LauncherView.Merge?
    let box = NSBox()
    let joinRow = NSStackView()
    private lazy var boxHeight = box.heightAnchor.constraint(
        equalToConstant: Self.boxHeights.lowerBound)
    private var fittedWidth: CGFloat = 0

    var text: String { editor.string }

    var isEditing: Bool { unsafe window?.firstResponder === editor }

    private var separator: String {
        Self.separators[max(joinMenu.indexOfSelectedItem, 0)].value
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        note.font = .systemFont(ofSize: Self.noteSize)
        note.textColor = .secondaryLabelColor
        note.isSelectable = false
        configureJoin()
        configureEditor()
        strip.target = self
        strip.action = #selector(stripFormatting)
        snippet.target = self
        snippet.action = #selector(saveSnippet)
        layoutPane()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func join(_ texts: [String], with separator: String) -> String {
        texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }

    static func stripped(_ text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func show(_ next: LauncherView.Merge?, focusing: Bool) {
        isHidden = next == nil
        guard let next else {
            merge = nil
            return
        }
        let changed = next != merge
        merge = next
        title.stringValue = next.title
        note.stringValue = next.note
        joinRow.isHidden = !next.joins
        if changed { rebuild() }
        if focusing { focus() }
    }

    func rebuild() {
        guard let merge else { return }
        editor.string = merge.joins ? Self.join(merge.texts, with: separator) : merge.texts.joined()
        editor.undoManager?.removeAllActions()
        fitBox()
    }

    func focus() {
        unsafe window?.makeFirstResponder(editor)
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
    }

    override func layout() {
        super.layout()
        guard bounds.width != fittedWidth else { return }
        fittedWidth = bounds.width
        fitBox()
    }

    func textDidChange(_: Notification) {
        fitBox()
    }

    func textView(_: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation) else { return false }
        onEscape?()
        return true
    }

    private func fitBox() {
        guard let container = unsafe editor.textContainer,
            let layout = unsafe editor.layoutManager
        else { return }
        layout.ensureLayout(for: container)
        let wanted = ceil(layout.usedRect(for: container).height) + Self.textInset + Self.textInset
        boxHeight.constant = min(
            max(wanted, Self.boxHeights.lowerBound), Self.boxHeights.upperBound)
    }

    private func focusChanged(_ focused: Bool) {
        onFocus?(focused)
        box.borderColor =
            focused ? .controlAccentColor.withAlphaComponent(Self.focusAlpha) : DetailPane.edge
        box.borderWidth = focused ? Self.focusWidth : 1
    }

    @objc
    private func joinChanged() {
        rebuild()
    }

    @objc
    private func stripFormatting() {
        let whole = NSRange(location: 0, length: editor.string.utf16.count)
        let cleaned = Self.stripped(editor.string)
        guard cleaned != editor.string,
            editor.shouldChangeText(in: whole, replacementString: cleaned)
        else { return }
        editor.replaceCharacters(in: whole, with: cleaned)
        editor.didChangeText()
    }

    @objc
    private func saveSnippet() {
        onSnippet?(editor.string)
    }

    private func configureJoin() {
        for choice in Self.separators {
            joinMenu.addItem(withTitle: choice.title)
        }
        joinMenu.controlSize = .small
        joinMenu.font = .systemFont(ofSize: Self.joinSize)
        joinMenu.target = self
        joinMenu.action = #selector(joinChanged)
        joinMenu.setAccessibilityLabel("Join with")
        let label = NSTextField(labelWithString: "Join with")
        label.font = .systemFont(ofSize: Self.joinSize)
        label.textColor = .secondaryLabelColor
        joinRow.setViews([label, joinMenu], in: .leading)
        joinRow.spacing = Self.joinGap
        joinRow.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func configureEditor() {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = Self.textSize * Self.lineHeight
        style.maximumLineHeight = style.minimumLineHeight
        editor.delegate = self
        editor.onFocusChange = { [weak self] in self?.focusChanged($0) }
        editor.setAccessibilityLabel("Text to paste")
        editor.isRichText = false
        editor.allowsUndo = true
        editor.drawsBackground = false
        editor.turnOffSubstitutions()
        editor.insertionPointColor = .controlAccentColor
        editor.textContainerInset = NSSize(width: Self.textInset, height: Self.textInset)
        unsafe editor.textContainer?.lineFragmentPadding = 0
        editor.font = .systemFont(ofSize: Self.textSize)
        editor.textColor = .labelColor
        editor.defaultParagraphStyle = style
        editor.typingAttributes = [
            .font: NSFont.systemFont(ofSize: Self.textSize), .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
        editor.minSize = .zero
        editor.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        unsafe editor.textContainer?.widthTracksTextView = true
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = editor
        box.boxType = .custom
        box.cornerRadius = Self.boxRadius
        box.borderWidth = 1
        box.fillColor = Self.fill
        box.borderColor = DetailPane.edge
        box.contentViewMargins = .zero
        box.contentView = scroll
    }

    private func layoutPane() {
        let divider = NSBox()
        divider.boxType = .separator
        let buttons = NSStackView(views: [strip, snippet])
        buttons.spacing = Self.buttonGap
        for view in [divider, title, joinRow, box, note, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            title.topAnchor.constraint(equalTo: topAnchor, constant: Self.top),
            title.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: Self.side),
            joinRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            joinRow.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            title.trailingAnchor.constraint(
                lessThanOrEqualTo: joinRow.leadingAnchor, constant: -Self.gap),
            box.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Self.titleGap),
            box.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            box.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            boxHeight,
            note.topAnchor.constraint(equalTo: box.bottomAnchor, constant: Self.gap),
            note.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            note.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            buttons.topAnchor.constraint(equalTo: note.bottomAnchor, constant: Self.gap),
            buttons.leadingAnchor.constraint(equalTo: box.leadingAnchor),
        ])
    }
}
