import AppKit

extension SnippetEditor {
    static let newSize: CGFloat = 13
    static let newHeight: CGFloat = 26
    private static let chipSize: CGFloat = 11.5
    static let chipFont = NSFont.monospacedSystemFont(ofSize: chipSize, weight: .regular)
    static let capsuleInset: CGFloat = 10
    private static let barHeight: CGFloat = 60
    private static let barInset: CGFloat = 20
    private static let barTrailing: CGFloat = 14
    private static let barGap: CGFloat = 12
    private static let searchSize: CGFloat = 20
    private static let listWidth: CGFloat = 260
    private static let listInset: CGFloat = 8
    private static let paneTop: CGFloat = 12
    private static let paneSide: CGFloat = 16
    private static let paneBottom: CGFloat = 62
    private static let paneGap: CGFloat = 12
    private static let labelGap: CGFloat = 4
    private static let boxLabelGap: CGFloat = 6
    private static let columnGap: CGFloat = 10
    private static let keywordWidth: CGFloat = 150
    private static let labelSize: CGFloat = 12
    private static let textSize: CGFloat = 13.5
    private static let lineHeight: CGFloat = 1.7
    private static let textSide: CGFloat = 10
    private static let textTop: CGFloat = 12
    private static let boxRadius: CGFloat = 12
    private static let chipGap: CGFloat = 6
    private static let insertGap: CGFloat = 10
    private static let rowTop: CGFloat = 6
    private static let rowSide: CGFloat = 12
    private static let rowHeight: CGFloat = 36
    private static let detailGap: CGFloat = 2
    private static let buttonsInset: CGFloat = 5
    private static let buttonsGap: CGFloat = 6
    private static let tokenSize: CGFloat = 12
    private static let fillAlpha = (dark: 0.22, light: 0.04)
    private static let edgeAlpha = (dark: 0.08, light: 0.10)
    private static let tokenAlpha = (dark: 0.22, light: 0.12)
    private static let tokenLift: CGFloat = 0.45
    private static let tokenText = SheetForm.adaptive(
        dark: NSColor.systemBlue.blended(withFraction: tokenLift, of: .white) ?? .systemBlue,
        light: .systemBlue)
    private static let tokenFill = SheetForm.adaptive(
        dark: .systemBlue.withAlphaComponent(tokenAlpha.dark),
        light: .systemBlue.withAlphaComponent(tokenAlpha.light))

    private static var textAttributes: [NSAttributedString.Key: Any] {
        let style = NSMutableParagraphStyle()
        style.minimumLineHeight = (textSize * lineHeight).rounded()
        style.maximumLineHeight = style.minimumLineHeight
        return [
            .font: NSFont.systemFont(ofSize: textSize), .foregroundColor: NSColor.labelColor,
            .paragraphStyle: style,
        ]
    }

    static func capsule(_ buttons: [NSView]) -> NSView {
        let stack = NSStackView()
        for (index, button) in buttons.enumerated() {
            if index > 0 {
                let divider = FloatingCapsule.divider()
                stack.addArrangedSubview(divider)
                stack.setCustomSpacing(buttonsGap, after: divider)
            }
            stack.addArrangedSubview(button)
            stack.setCustomSpacing(buttonsGap, after: button)
        }
        return FloatingCapsule.make(stack, leading: buttonsInset, trailing: buttonsInset)
    }

    func insert(_ token: String) {
        unsafe window?.makeFirstResponder(textView)
        let inserted = token == Self.fillIn ? fillInToken : token
        let start = textView.selectedRange().location
        textView.insertText(inserted, replacementRange: textView.selectedRange())
        guard token == Self.fillIn, let quoted = inserted.firstMatch(of: /"(?<name>[^"]*)"/)
        else { return }
        let name = quoted.output.name
        let range = NSRange(name.startIndex..<name.endIndex, in: inserted)
        textView.setSelectedRange(NSRange(location: start + range.location, length: range.length))
    }

    func highlightTokens() {
        guard !textView.hasMarkedText(), let storage = unsafe textView.textStorage else { return }
        storage.beginEditing()
        storage.setAttributes(
            Self.textAttributes, range: NSRange(location: 0, length: storage.length))
        for range in tokens(storage.string) {
            storage.addAttributes(
                [
                    .font: NSFont.monospacedSystemFont(ofSize: Self.tokenSize, weight: .regular),
                    .foregroundColor: Self.tokenText, .backgroundColor: Self.tokenFill,
                ], range: range)
        }
        storage.endEditing()
    }

    func layoutEditor() {
        let bar = layoutBar()
        let divider = NSBox()
        divider.boxType = .separator
        let pane = layoutPane()
        empty.font = .systemFont(ofSize: Self.labelSize)
        empty.textColor = .secondaryLabelColor
        list.contentInsets.bottom = Self.capsuleInset + FloatingCapsule.height + Self.capsuleInset
        for view in [bar, list, empty, divider, pane, contextPill, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.leadingAnchor.constraint(equalTo: leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.barHeight),
            list.topAnchor.constraint(equalTo: bar.bottomAnchor),
            list.bottomAnchor.constraint(equalTo: bottomAnchor),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.listInset),
            list.trailingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.listWidth - Self.listInset),
            empty.centerXAnchor.constraint(equalTo: list.centerXAnchor),
            empty.topAnchor.constraint(equalTo: list.topAnchor, constant: Self.barHeight),
            divider.topAnchor.constraint(equalTo: bar.bottomAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.listWidth),
            divider.widthAnchor.constraint(equalToConstant: 1),
            pane.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: Self.paneTop),
            pane.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: Self.paneSide),
            pane.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.paneSide),
            pane.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.paneBottom),
        ])
        placeCapsules()
    }

    private func placeCapsules() {
        NSLayoutConstraint.activate([
            contextPill.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            contextPill.centerYAnchor.constraint(equalTo: buttons.centerYAnchor),
            buttons.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.capsuleInset),
            buttons.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        unsafe nextKeyView = search
        unsafe search.nextKeyView = nameField
        unsafe nameField.nextKeyView = keywordField
        unsafe keywordField.nextKeyView = textView
        unsafe textView.nextKeyView = search
    }

    private func layoutBar() -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: Self.searchSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        search.placeholderString = "Search snippets…"
        search.setAccessibilityLabel("Search snippets")
        search.font = .systemFont(ofSize: Self.searchSize)
        search.isBordered = false
        search.drawsBackground = false
        search.focusRingType = .none
        search.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        newSnippet.title = "New Snippet"
        let bar = NSStackView(views: [icon, search, newSnippet])
        bar.spacing = Self.barGap
        bar.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.barInset, bottom: 0, right: Self.barTrailing)
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(separator)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
        return bar
    }

    private func layoutPane() -> NSView {
        let mono = NSFont.monospacedSystemFont(ofSize: SheetForm.fontSize, weight: .regular)
        let name = labelled(
            "Name",
            SheetForm.field(nameField, label: "Snippet name", width: nil, font: SheetForm.font))
        let keyword = labelled(
            "Keyword", SheetForm.field(keywordField, label: "Keyword", width: nil, font: mono))
        keyword.widthAnchor.constraint(equalToConstant: Self.keywordWidth).isActive = true
        let fields = NSStackView(views: [name, keyword])
        fields.spacing = Self.columnGap
        fields.alignment = .top
        problemLabel.textColor = .systemOrange
        problemLabel.isHidden = true
        let snippet = labelled("Snippet", layoutText())
        snippet.spacing = Self.boxLabelGap
        let insert = NSStackView(views: [label("Insert")] + chips)
        insert.spacing = Self.chipGap
        insert.setCustomSpacing(Self.insertGap, after: insert.views[0])
        let pane = NSStackView(views: [fields, problemLabel, snippet, insert, layoutExpandRow()])
        pane.orientation = .vertical
        pane.alignment = .leading
        pane.spacing = Self.paneGap
        for view in [fields, snippet, pane.views.last].compactMap(\.self) {
            view.widthAnchor.constraint(equalTo: pane.widthAnchor).isActive = true
        }
        snippet.setContentHuggingPriority(.defaultLow, for: .vertical)
        return pane
    }

    private func layoutText() -> NSView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = textView
        textView.setAccessibilityLabel("Snippet text")
        textView.isRichText = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.textContainerInset = NSSize(width: Self.textSide, height: Self.textTop)
        textView.typingAttributes = Self.textAttributes
        textView.minSize = .zero
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        unsafe textView.textContainer?.widthTracksTextView = true
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Self.boxRadius
        box.borderWidth = 1
        box.fillColor = SheetForm.adaptive(
            dark: .black.withAlphaComponent(Self.fillAlpha.dark),
            light: .black.withAlphaComponent(Self.fillAlpha.light))
        box.borderColor = SheetForm.adaptive(
            dark: .white.withAlphaComponent(Self.edgeAlpha.dark),
            light: .black.withAlphaComponent(Self.edgeAlpha.light))
        box.contentViewMargins = .zero
        box.contentView = scroll
        return box
    }

    private func layoutExpandRow() -> NSView {
        let title = NSTextField(labelWithString: "Expand in every app")
        title.font = SheetForm.font
        let text = NSStackView(views: [title, expandDetail])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = Self.detailGap
        expandSwitch.setAccessibilityLabel("Expand in every app")
        let row = NSStackView(views: [text, expandSwitch])
        row.distribution = .equalSpacing
        row.edgeInsets = NSEdgeInsets(
            top: Self.rowTop, left: Self.rowSide, bottom: Self.rowTop, right: Self.rowSide)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: Self.rowHeight).isActive = true
        return row
    }

    private func labelled(_ title: String, _ view: NSView) -> NSStackView {
        let stack = NSStackView(views: [label(title), view])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.labelGap
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func label(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: Self.labelSize)
        label.textColor = .secondaryLabelColor
        return label
    }
}
