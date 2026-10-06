import AppKit

final class WidgetEditBar: NSStackView {
    struct Subject: Equatable {
        let name: String
        let spot: WidgetGrid.Spot
        let sizes: [WidgetSizeSwitch.Option]
        let current: WidgetGrid.Size
    }

    enum Grouping {
        case off
        case group
        case ungroup
    }

    struct State: Equatable {
        let widget: Subject?
        let moving: Bool
        let count: Int
        let grouping: Grouping
        let hint: String?
        let symbol: String
        let undoable: Bool
        let width: CGFloat
    }

    private static let sizeChoices = 2
    private static let nameFloor: CGFloat = 60
    private static let gap: CGFloat = 10
    private static let nameSize: CGFloat = 13
    private static let nameGap: CGFloat = 10
    private static let buttonHeight: CGFloat = 28
    private static let removeSize: CGFloat = 15
    private static let inspectorLeading: CGFloat = 12
    private static let inspectorTrailing: CGFloat = 4
    private static let hintHeight: CGFloat = 36
    private static let hintRadius: CGFloat = 12
    private static let hintLeading: CGFloat = 11
    private static let hintTrailing = (plain: 11.0, undo: 6.0)
    private static let hintGap: CGFloat = 8
    private static let hintSize: CGFloat = 13
    private static let undoHeight: CGFloat = 26
    private static let nameGives = NSLayoutConstraint.Priority.windowSizeStayPut - 1
    private static let hintGives = nameGives - 1
    static let moveSymbol = "arrow.up.and.down.and.arrow.left.and.right"

    let name = NSTextField(labelWithString: "")
    let move = CapsuleButton(
        "", keys: [], symbol: WidgetEditBar.moveSymbol, height: WidgetEditBar.buttonHeight)
    let group = CapsuleButton(
        "Group", keys: ["⌘", "G"], symbol: "square.on.square", height: WidgetEditBar.buttonHeight)
    let ungroup = CapsuleButton(
        "Ungroup", keys: ["⇧", "⌘", "G"], symbol: "square.on.square.dashed",
        height: WidgetEditBar.buttonHeight)
    let sizes = WidgetSizeSwitch()
    let remove = NSButton()
    private let divider = FloatingCapsule.divider()
    private let sizeDivider = FloatingCapsule.divider()
    let hintIcon = NSImageView()
    let hint = NSTextField(labelWithString: "")
    let undo = CapsuleButton(
        "Undo", keys: ["⌘", "Z"], symbol: nil, height: WidgetEditBar.undoHeight)
    private let hintStack: NSStackView
    let inspector: GlassView
    let notice: GlassView
    private var shown: State?
    var onSize: ((WidgetGrid.Size) -> Void)?
    var onMove: (() -> Void)?
    var onGroup: (() -> Void)?
    var onUngroup: (() -> Void)?
    var onRemove: (() -> Void)?
    var onUndo: (() -> Void)?

    init() {
        name.font = .systemFont(ofSize: Self.nameSize, weight: .semibold)
        name.lineBreakMode = .byTruncatingTail
        name.setContentCompressionResistancePriority(Self.nameGives, for: .horizontal)
        remove.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        remove.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .medium)
        remove.contentTintColor = .systemRed
        remove.isBordered = false
        remove.refusesFirstResponder = true
        let tools = NSStackView(
            views: [name, sizes, sizeDivider, move, group, ungroup, divider, remove])
        tools.setCustomSpacing(Self.nameGap, after: name)
        inspector = FloatingCapsule.make(
            tools, leading: Self.inspectorLeading, trailing: Self.inspectorTrailing)
        hintIcon.symbolConfiguration = .init(pointSize: Self.hintSize, weight: .medium)
        hintIcon.contentTintColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: Self.hintSize, weight: .medium)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byTruncatingTail
        hint.setContentCompressionResistancePriority(Self.hintGives, for: .horizontal)
        hintStack = NSStackView(views: [hintIcon, hint, undo])
        hintStack.spacing = Self.hintGap
        notice = FloatingCapsule.make(
            hintStack, leading: Self.hintLeading, trailing: Self.hintTrailing.plain,
            height: Self.hintHeight, radius: Self.hintRadius)
        super.init(frame: .zero)
        remove.target = self
        remove.action = #selector(pressRemove)
        connectButtons()
        setViews([inspector, notice], in: .leading)
        spacing = Self.gap
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remove.widthAnchor.constraint(equalToConstant: Self.buttonHeight),
            remove.heightAnchor.constraint(equalToConstant: Self.buttonHeight),
        ])
        show(nil, moving: false, count: 0, grouping: .off)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ state: State) {
        guard state != shown else { return }
        shown = state
        show(state.widget, moving: state.moving, count: state.count, grouping: state.grouping)
        show(hint: state.hint, symbol: state.symbol, undoable: state.undoable)
        arrange(in: state.width)
    }

    private func show(_ widget: Subject?, moving: Bool, count: Int, grouping: Grouping) {
        inspector.isHidden = widget == nil
        guard let widget else { return }
        let several = count > 1
        name.stringValue = several ? "\(count) widgets" : widget.name
        for view: NSView in [move, divider, remove] {
            view.isHidden = several
        }
        sizes.isHidden = several || widget.sizes.count < Self.sizeChoices
        sizeDivider.isHidden = sizes.isHidden
        sizes.show(widget.sizes, current: widget.current)
        group.isHidden = grouping != .group
        ungroup.isHidden = grouping != .ungroup
        move.label.stringValue = widget.spot.title
        move.setAccessibilityValue(widget.spot.title)
        move.fillColor = moving ? .controlAccentColor : .clear
        move.label.textColor = moving ? .white : .labelColor
        move.icon.contentTintColor = move.label.textColor
        remove.setAccessibilityLabel("Remove \(widget.name)")
        setAccessibilityLabel("\(name.stringValue) options")
    }

    private func show(hint text: String?, symbol: String, undoable: Bool) {
        notice.isHidden = text == nil
        hint.stringValue = text ?? ""
        hintIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        undo.isHidden = !undoable
        hintStack.edgeInsets.right = undoable ? Self.hintTrailing.undo : Self.hintTrailing.plain
    }

    private func connectButtons() {
        sizes.onPick = { [weak self] size in self?.onSize?(size) }
        move.onPress = { [weak self] in self?.onMove?() }
        group.onPress = { [weak self] in self?.onGroup?() }
        ungroup.onPress = { [weak self] in self?.onUngroup?() }
        undo.onPress = { [weak self] in self?.onUndo?() }
        move.setAccessibilityLabel("Move to…")
    }

    private func arrange(in width: CGFloat) {
        let nameWidth = name.fittingSize.width
        let needed = inspector.fittingSize.width - nameWidth + Self.nameFloor
        if !sizes.isHidden, needed > width {
            sizes.isHidden = true
            sizeDivider.isHidden = true
        }
        let beside = inspector.fittingSize.width + spacing + notice.fittingSize.width <= width
        let stacked = !beside && !inspector.isHidden && !notice.isHidden
        orientation = stacked ? .vertical : .horizontal
        alignment = stacked ? .leading : .centerY
        setViews(stacked ? [notice, inspector] : [inspector, notice], in: .leading)
    }

    @objc
    private func pressRemove() {
        onRemove?()
    }
}
