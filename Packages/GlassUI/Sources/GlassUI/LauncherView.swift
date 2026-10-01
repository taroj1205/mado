public import AppKit
import Carbon.HIToolbox

public final class LauncherView: NSView, NSTextFieldDelegate {
    private static let searchBarHeight: CGFloat = 60
    private static let searchInset: CGFloat = 20
    private static let searchFontSize: CGFloat = 20
    private static let searchIconGap: CGFloat = 12
    private static let resultsInset: CGFloat = 8
    private static let capsuleInset: CGFloat = 10
    private static let actionGap: CGFloat = 8
    private static let actionLeading: CGFloat = 17
    private static let actionTrailing: CGFloat = 10
    private static let dividerGap: CGFloat = 11
    private static let actionsGap: CGFloat = 18
    private static let shortcutGap: CGFloat = 3
    private static let contextLeading: CGFloat = 11
    private static let contextTrailing: CGFloat = 16
    private static let contextIconSize: CGFloat = 17
    private static let previewHint = "Space to preview"
    private static let returnKeys: Set<String?> = ["\r", "\u{3}"]
    private static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    public let field = NSTextField()
    public let results = ResultList()
    public var onQuery: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onRun: ((ResultList.Item, Int) -> Void)?
    public var context: String? {
        didSet { showContext() }
    }

    let actionLabel = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let contextLabel = FloatingCapsule.label(weight: .regular, color: .secondaryLabelColor)
    let actionCapsule: GlassView
    let contextCapsule: GlassView
    private(set) var preview: FilePreview?
    private var browsing = false

    var previewing: Bool { preview?.isVisible == true }
    public var sharing: Bool { preview?.sharing == true }

    private var canPreview: Bool {
        (browsing || previewing) && results.selectedItem?.file != nil
    }

    override public init(frame: NSRect) {
        actionCapsule = Self.makeActionCapsule(actionLabel)
        contextCapsule = Self.makeContextCapsule(contextLabel)
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
        field.delegate = self
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
        placeCapsules()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func makeActionCapsule(_ label: NSTextField) -> GlassView {
        let enter = FloatingCapsule.keycap("↵")
        let divider = FloatingCapsule.divider()
        let actions = FloatingCapsule.label(weight: .medium, color: .labelColor)
        actions.stringValue = "Actions"
        let command = FloatingCapsule.keycap("⌘")
        let stack = NSStackView(views: [
            label, enter, divider, actions, command, FloatingCapsule.keycap("K"),
        ])
        stack.spacing = Self.actionGap
        stack.setCustomSpacing(Self.dividerGap, after: enter)
        stack.setCustomSpacing(Self.actionsGap, after: divider)
        stack.setCustomSpacing(Self.shortcutGap, after: command)
        return FloatingCapsule.make(
            stack, leading: Self.actionLeading, trailing: Self.actionTrailing)
    }

    private static func makeContextCapsule(_ label: NSTextField) -> GlassView {
        let icon = NSImageView()
        icon.image = NSImage(
            systemSymbolName: "chevron.forward.circle.fill", accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(
            pointSize: Self.contextIconSize, weight: .semibold
        )
        .applying(.init(paletteColors: [.white, .controlAccentColor]))
        let stack = NSStackView(views: [icon, label])
        stack.spacing = Self.actionGap
        return FloatingCapsule.make(
            stack, leading: Self.contextLeading, trailing: Self.contextTrailing)
    }

    private func placeCapsules() {
        addSubview(contextCapsule)
        addSubview(actionCapsule)
        NSLayoutConstraint.activate([
            contextCapsule.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            contextCapsule.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -Self.capsuleInset),
            actionCapsule.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.capsuleInset),
            actionCapsule.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        results.contentInsets.bottom =
            Self.capsuleInset + FloatingCapsule.height + Self.capsuleInset
        results.onSelect = { [weak self] item in self?.showAction(of: item) }
        showAction(of: nil)
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command,
            Self.returnKeys.contains(event.charactersIgnoringModifiers),
            let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return super.performKeyEquivalent(with: event) }
        run(1)
        return true
    }

    public func handleKeyDown(_ event: NSEvent) -> Bool {
        guard event.keyCode == kVK_Space,
            event.modifierFlags.isDisjoint(with: Self.modifierKeys),
            canPreview, let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return false }
        togglePreview()
        return true
    }

    public func controlTextDidChange(_: Notification) {
        browsing = false
        closePreview()
        showContext()
        onQuery?(field.stringValue)
    }

    public func control(
        _: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp):
            results.selectPrevious()
            selectionMoved()

        case #selector(NSResponder.moveDown):
            results.selectNext()
            selectionMoved()

        case #selector(NSResponder.insertNewline) where !textView.hasMarkedText(): run(0)
        case #selector(NSResponder.cancelOperation) where previewing: closePreview()
        case #selector(NSResponder.cancelOperation): onCancel?()
        default: return false
        }
        return true
    }

    private func showAction(of item: ResultList.Item?) {
        actionLabel.stringValue = item?.action ?? ""
        actionCapsule.isHidden = item == nil
        showContext()
    }

    private func showContext() {
        let text = canPreview ? Self.previewHint : context
        contextLabel.stringValue = text ?? ""
        contextCapsule.isHidden = text == nil
    }

    public func closePreview() {
        preview?.close()
    }

    private func togglePreview() {
        if previewing {
            closePreview()
        } else {
            showPreview()
        }
    }

    private func showPreview() {
        guard let file = results.selectedItem?.file, let window = unsafe window,
            let visible = window.screen?.visibleFrame
        else {
            closePreview()
            return
        }
        let card = preview ?? FilePreview()
        card.onOpen = { [weak self] in self?.run(0) }
        card.onShareEnd = { [weak self] shared in self?.shareEnded(shared) }
        preview = card
        card.show(file, beside: window.frame, in: visible)
    }

    private func shareEnded(_ shared: Bool) {
        if shared {
            onCancel?()
        } else {
            unsafe window?.makeKey()
        }
    }

    private func selectionMoved() {
        browsing = true
        showContext()
        if previewing {
            showPreview()
        }
    }

    private func run(_ action: Int) {
        guard let item = results.selectedItem else { return }
        onRun?(item, action)
    }
}
