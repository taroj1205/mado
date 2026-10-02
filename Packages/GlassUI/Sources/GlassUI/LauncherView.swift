public import AppKit
import Carbon.HIToolbox

public final class LauncherView: NSView, NSTextFieldDelegate {
    private static let searchBarHeight: CGFloat = 60
    private static let searchInset: CGFloat = 20
    private static let searchFontSize: CGFloat = 20
    private static let searchIconGap: CGFloat = 12
    private static let resultsInset: CGFloat = 8
    static let capsuleInset: CGFloat = 10
    private static let previewHint = "Space to preview"
    static let returnKeys: Set<String?> = ["\r", "\u{3}"]
    static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    public let field = NSTextField()
    public let results = ResultList()
    public var onQuery: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onRun: ((ResultList.Item, Int) -> Void)?
    public var actionTitles: ((ResultList.Item) -> [String])?
    public var context: String? {
        didSet { showContext() }
    }

    let actionLabel = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let contextLabel = FloatingCapsule.label(weight: .regular, color: .secondaryLabelColor)
    let actionsToggle = LauncherView.makeActionsToggle()
    let actionCapsule: GlassView
    let contextCapsule: GlassView
    private(set) var preview: FilePreview?
    var actionPanel: ActionPanel?
    private var browsing = false

    var previewing: Bool { preview?.isVisible == true }
    public var sharing: Bool { preview?.sharing == true }
    public var choosingAction: Bool { actionPanel?.isVisible == true }

    private var canPreview: Bool {
        (browsing || previewing) && results.selectedItem?.file != nil
    }

    override public init(frame: NSRect) {
        actionCapsule = Self.makeActionCapsule(actionLabel, actionsToggle)
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
        results.onSelect = { [weak self] item in self?.selectionChanged(to: item) }
        results.onMove = { [weak self] in self?.selectionMoved() }
        field.setAccessibilitySharedFocusElements([results.table])
        showAction(of: nil)
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if choosingAction, let actionPanel {
            return actionPanel.performShortcut(event) || super.performKeyEquivalent(with: event)
        }
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command,
            let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case let key where Self.returnKeys.contains(key): run(1)
        case "k" where results.selectedItem != nil: showActions()
        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    public func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            return previewKey(event)

        case .leftMouseDown
        where field.convert(field.bounds, to: nil).contains(event.locationInWindow):
            endBrowsing()
            return false

        case .leftMouseDown:
            if actionPanel?.contains(event.locationInWindow) != true {
                closeActions()
            }
            return false

        default:
            return false
        }
    }

    private func previewKey(_ event: NSEvent) -> Bool {
        guard event.keyCode == kVK_Space,
            event.modifierFlags.isDisjoint(with: Self.modifierKeys),
            canPreview, let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return false }
        togglePreview()
        return true
    }

    public func controlTextDidChange(_: Notification) {
        endBrowsing()
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

        default:
            endBrowsing()
            return false
        }
        return true
    }

    private func selectionChanged(to item: ResultList.Item?) {
        showAction(of: item)
        if previewing {
            showPreview()
        }
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

    public func show(_ sections: [ResultList.Section]) {
        let previewed = results.selectedItem?.file
        let keep = browsing || choosingAction
        results.update(sections, keepingSelectionOf: keep ? results.selectedItem?.id : nil)
        if results.selectedItem?.file != previewed {
            closePreview()
        }
    }

    public func endBrowsing() {
        browsing = false
        closePreview()
        closeActions()
        showContext()
    }

    func closePreview() {
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
    }

    private func run(_ action: Int) {
        guard let item = results.selectedItem else { return }
        onRun?(item, action)
    }
}
