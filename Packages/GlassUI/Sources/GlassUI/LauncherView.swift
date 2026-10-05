public import AppKit

public final class LauncherView: NSView {
    static let searchBarHeight: CGFloat = 60
    static let searchInset: CGFloat = 20
    static let searchSymbol = "magnifyingglass"
    private static let searchFontSize: CGFloat = 20
    static let searchIconGap: CGFloat = 12
    static let searchPlaceholder = "Search apps and commands…"
    static let backInset: CGFloat = 14
    static let resultsInset: CGFloat = 8
    static let capsuleInset: CGFloat = 10
    static let previewHint = "⌘Y to preview"
    static let previewSymbol = "eye"
    static let previewKeys = ["⌘", "Y"]
    static let returnKeys: Set<String?> = ["\r", "\u{3}"]
    static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    public let field = NSTextField()
    private(set) lazy var back = BackButton(target: self, action: #selector(leave))
    public let results = ResultList()
    public var onQuery: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onLeave: (() -> Void)?
    public var onRun: ((ResultList.Item, Int) -> Void)?
    public var actions: ((ResultList.Item) -> [Action])?
    public var shortcutKeys: [[String]] = []
    public var onPill: ((StatusBar.Pill) -> Void)?
    public var onFit: (() -> Void)?
    public let emojiGrid = EmojiGrid()
    public var onStatusLayout: ((StatusBarLayout) -> Void)?
    public var pills: [StatusBar.Pill] = [] {
        didSet { arrangePills() }
    }
    public var statusLayout = StatusBarLayout() {
        didSet { arrangePills() }
    }
    public var onWidget: ((WidgetGrid.Widget) -> Void)?
    public var onSkip: ((WidgetGrid.Skip) -> Void)?
    public var onPage: ((WidgetGrid.Page) -> Void)?
    public var onSeek: ((Int) -> Void)?
    public var onWidgetEdit: ((WidgetSettings.Edit) -> Void)?
    public var onUndoWidgetEdit: (() -> Void)?
    public var onEdit: ((ResultList.Item) -> Void)?
    public var onWidgetEditing: ((Bool) -> Void)?
    public internal(set) var editingWidgets = false
    public var context: String? {
        didSet { showContext() }
    }
    public var contextSymbol: String? {
        didSet { showContext() }
    }
    public var capsuleSlots = CapsuleSlot.standard {
        didSet { showAction(of: selectedItem) }
    }

    let actionLabel = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let actionsToggle = LauncherView.makeActionsToggle()
    let actionKeycap = FloatingCapsule.keycap("↵")
    let actionCapsule: GlassView
    let contextPill = StatusPill()
    let statusBar = StatusBar()
    var selectedPill: Int?
    var customiser: StatusBarCustomiser?
    let widgetGrid = WidgetGrid()
    let detail = DetailPane()
    let comparisonPane = ComparisonPane()
    let mergePane = MergePane()
    let calendarPane = CalendarPane()
    let chip = ScopeChip()
    var shownDetail: Detail?
    var fittedForCalendarAnswer = false
    var gridHome: String?
    var filter: NSPopUpButton?
    let editBar = WidgetEditBar()
    let gallery = WidgetGallery()
    let doneButton = CapsuleButton.accent("Done", keys: ["↵"], height: LauncherView.doneHeight)
    var widgetNote: (text: String, undoable: Bool)?
    var queryBeforeEditing: String?
    var selectedWidget: Int?
    private(set) var preview: FilePreview?
    var actionPanel: ActionPanel?
    var spotPicker: WidgetSpotPicker?
    private(set) var browsing = false
    var isKeyRepeat = { NSApp.currentEvent.map { $0.type == .keyDown && $0.isARepeat } ?? false }
    var passKeyOn = { (event: NSEvent) in _ = NSApp.mainMenu?.performKeyEquivalent(with: event) }
    var rootQuery: String?
    var shownQuery = (text: "", scoped: false)
    var afterResults: (() -> Void)?
    let icon = NSImageView()
    lazy var fieldLeading = field.leadingAnchor.constraint(
        equalTo: icon.trailingAnchor, constant: Self.searchIconGap)
    lazy var fieldTrailing = field.trailingAnchor.constraint(
        equalTo: trailingAnchor, constant: -Self.searchInset)
    lazy var resultsTrailing = results.trailingAnchor.constraint(
        equalTo: trailingAnchor, constant: -Self.resultsInset)
    lazy var calendarTop = calendarPane.topAnchor.constraint(equalTo: results.topAnchor)

    var previewing: Bool { preview?.isVisible == true }
    public var sharing: Bool { preview?.sharing == true }
    public var choosingAction: Bool { actionPanel?.isVisible == true }

    override public init(frame: NSRect) {
        actionCapsule = Self.makeActionCapsule()
        super.init(frame: frame)
        icon.image = NSImage(systemSymbolName: Self.searchSymbol, accessibilityDescription: nil)
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
        for view in [
            icon, back, chip, field, separator, widgetGrid, results, detail, comparisonPane,
            mergePane, calendarPane, emojiGrid,
        ] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        placeSearchBar(bar)
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.topAnchor.constraint(equalTo: bar.bottomAnchor),
            results.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.resultsInset),
            resultsTrailing,
            results.topAnchor.constraint(equalTo: widgetGrid.bottomAnchor),
            results.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        placeWidgets(below: separator)
        placeDetail(below: separator)
        placeGrid(below: separator)
        placeCapsules()
        placeMerge()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func layout() {
        super.layout()
        widgetGrid.placeFloats()
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        if choosingAction || editingWidgets {
            return overlayShortcut(event) || super.performKeyEquivalent(with: event)
        }
        if handleModifiedKey(event) || holdsForResults(event) { return true }
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command,
            let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return runActionShortcut(event) || super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case let key where Self.returnKeys.contains(key): run(keyed: Action.secondaryKeys)
        case "k" where selectedItem != nil: showActions()
        case "y" where selectedItem?.file != nil: togglePreview()

        case let key?:
            return runActionShortcut(event) || scopeShortcut(key) || runShortcut(key)
                || super.performKeyEquivalent(with: event)

        default: return super.performKeyEquivalent(with: event)
        }
        return true
    }

    override public func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        draggingUpdated(sender)
    }

    override public func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        dragWidget(
            sender.draggingPasteboard.string(forType: WidgetGrid.dragType),
            at: sender.draggingLocation, from: sender.draggingSource)
    }

    override public func draggingEnded(_: any NSDraggingInfo) {
        endWidgetDrag()
    }

    override public func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        dropWidget(sender.draggingPasteboard.string(forType: WidgetGrid.dragType))
    }

    func selectionChanged(to item: ResultList.Item?) {
        endMergeEdit(for: item)
        showAction(of: item)
        showDetail(of: item)
        if previewing {
            showPreview()
        }
    }

    public func endBrowsing() {
        afterResults = nil
        finishEditingWidgets()
        restoreQueryBeforeEditing()
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
        guard let file = selectedItem?.file, let window = unsafe window,
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
        if mergePane.isEditing { unsafe window?.makeFirstResponder(field) }
        leavePillsAndWidgets()
        browsing = true
        showContext()
    }
}
