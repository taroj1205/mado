public import AppKit

public final class LauncherView: NSView {
    private static let searchBarHeight: CGFloat = 60
    private static let searchInset: CGFloat = 20
    private static let searchFontSize: CGFloat = 20
    static let searchIconGap: CGFloat = 12
    static let searchPlaceholder = "Search apps and commands…"
    private static let backInset: CGFloat = 14
    private static let resultsInset: CGFloat = 8
    static let capsuleInset: CGFloat = 10
    private static let previewHint = "⌘Y to preview"
    private static let previewSymbol = "eye"
    static let returnKeys: Set<String?> = ["\r", "\u{3}"]
    static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    public let field = NSTextField()
    private(set) lazy var back = BackButton(target: self, action: #selector(leave))
    public let results = ResultList()
    public var onQuery: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onRun: ((ResultList.Item, Int) -> Void)?
    public var actions: ((ResultList.Item) -> [Action])?
    public var onPill: ((StatusBar.Pill) -> Void)?
    public var onWidget: ((WidgetGrid.Widget) -> Void)?
    public var onSkip: ((WidgetGrid.Skip) -> Void)?
    public var context: String? {
        didSet { showContext() }
    }
    public var contextSymbol: String? {
        didSet { showContext() }
    }

    let actionLabel = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let actionsToggle = LauncherView.makeActionsToggle()
    let actionCapsule: GlassView
    let contextPill = StatusPill()
    let statusBar = StatusBar()
    var selectedPill: Int?
    let widgetGrid = WidgetGrid()
    var selectedWidget: Int?
    private(set) var preview: FilePreview?
    var actionPanel: ActionPanel?
    private var browsing = false
    var isKeyRepeat = { NSApp.currentEvent.map { $0.type == .keyDown && $0.isARepeat } ?? false }
    var rootQuery: String?
    let icon = NSImageView()
    lazy var fieldLeading = field.leadingAnchor.constraint(
        equalTo: icon.trailingAnchor, constant: Self.searchIconGap)

    var previewing: Bool { preview?.isVisible == true }
    public var sharing: Bool { preview?.sharing == true }
    public var choosingAction: Bool { actionPanel?.isVisible == true }

    override public init(frame: NSRect) {
        actionCapsule = Self.makeActionCapsule(actionLabel, actionsToggle)
        super.init(frame: frame)
        icon.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil)
        icon.symbolConfiguration = .init(pointSize: Self.searchFontSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        field.placeholderString = Self.searchPlaceholder
        field.font = .systemFont(ofSize: Self.searchFontSize)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        let separator = NSBox()
        separator.boxType = .separator
        let bar = NSLayoutGuide()
        addLayoutGuide(bar)
        for view in [icon, back, field, separator, widgetGrid, results] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: topAnchor),
            bar.heightAnchor.constraint(equalToConstant: Self.searchBarHeight),
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.searchInset),
            icon.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            back.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.backInset),
            back.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            fieldLeading,
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.searchInset),
            field.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: bar.bottomAnchor),
            results.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.resultsInset),
            results.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.resultsInset),
            results.topAnchor.constraint(equalTo: widgetGrid.bottomAnchor),
            results.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        placeWidgets(below: separator)
        placeCapsules()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func placeCapsules() {
        addSubview(contextPill)
        addSubview(statusBar)
        addSubview(actionCapsule)
        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.capsuleInset),
            statusBar.trailingAnchor.constraint(
                lessThanOrEqualTo: actionCapsule.leadingAnchor, constant: -Self.capsuleInset),
            statusBar.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor),
            contextPill.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: Self.capsuleInset),
            contextPill.centerYAnchor.constraint(equalTo: actionCapsule.centerYAnchor),
            actionCapsule.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.capsuleInset),
            actionCapsule.bottomAnchor.constraint(
                equalTo: bottomAnchor, constant: -Self.capsuleInset),
        ])
        results.contentInsets.bottom =
            Self.capsuleInset + FloatingCapsule.height + Self.capsuleInset
        results.onSelect = { [weak self] item in self?.selectionChanged(to: item) }
        results.onMove = { [weak self] in self?.selectionMoved() }
        results.onPick = { [weak self] query in self?.replaceQuery(with: query) }
        actionsToggle.onPress = { [weak self] in self?.toggleActions() }
        statusBar.onPress = { [weak self] index in self?.pressPill(index) }
        field.setAccessibilitySharedFocusElements([results.table])
        showAction(of: nil)
    }

    override public func layout() {
        super.layout()
        widgetGrid.placeFloats()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if choosingAction, let actionPanel {
            return actionPanel.performShortcut(event) || super.performKeyEquivalent(with: event)
        }
        if handleModifiedKey(event) { return true }
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command,
            let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return runActionShortcut(event) || super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case let key where Self.returnKeys.contains(key): runSecondary()
        case "k" where results.selectedItem != nil: showActions()
        case "y" where results.selectedItem?.file != nil: togglePreview()

        case let key?:
            return runActionShortcut(event) || runShortcut(key)
                || super.performKeyEquivalent(with: event)

        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    public func handle(_ event: NSEvent) -> Bool {
        switch event.type {
        case .leftMouseDown
        where field.convert(field.bounds, to: nil).contains(event.locationInWindow):
            endBrowsing()
            return false

        case .leftMouseDown:
            let point = event.locationInWindow
            let onToggle = actionsToggle.convert(actionsToggle.bounds, to: nil).contains(point)
            if !onToggle, actionPanel?.contains(point) != true {
                closeActions()
            }
            return false

        default:
            return false
        }
    }

    func replaceQuery(with query: String) {
        field.stringValue = query
        field.currentEditor()?.selectedRange = NSRange(location: query.utf16.count, length: 0)
        endBrowsing()
        onQuery?(query)
    }

    private func selectionChanged(to item: ResultList.Item?) {
        showAction(of: item)
        if previewing {
            showPreview()
        }
    }

    func showAction(of item: ResultList.Item?) {
        let action =
            selectedPill.map { pills[$0].action }
            ?? selectedWidget.map { widgetGrid.shown[$0].action }
            ?? item?.action
        actionLabel.stringValue = action ?? ""
        actionCapsule.isHidden = action == nil
        showContext()
    }

    func showContext() {
        statusBar.isHidden = !showsStatusBar
        widgetGrid.isHidden = !showsWidgets
        let hintsPreview = (browsing || previewing) && results.selectedItem?.file != nil
        let text = hintsPreview ? Self.previewHint : context
        contextPill.show(
            statusBar.isHidden ? text : nil,
            symbol: hintsPreview ? Self.previewSymbol : contextSymbol)
    }

    public func show(_ sections: [ResultList.Section]) {
        let previewed = results.selectedItem?.file
        let keep = browsing || choosingAction || selectedPill != nil || selectedWidget != nil
        results.update(sections, keepingSelectionOf: keep ? results.selectedItem?.id : nil)
        if results.selectedItem?.file != previewed {
            closePreview()
        }
    }

    public func endBrowsing() {
        browsing = false
        leavePillsAndWidgets()
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

    func selectionMoved() {
        leavePillsAndWidgets()
        browsing = true
        showContext()
    }

    func run(_ action: Int) {
        guard let item = results.selectedItem else { return }
        onRun?(item, action)
    }

    private func runSecondary() {
        guard let item = results.selectedItem,
            let index = actions?(item).firstIndex(where: { $0.keys == Action.secondaryKeys })
        else { return }
        onRun?(item, index)
    }
}
