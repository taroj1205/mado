import AppKit

final class WidgetEditBar: NSStackView {
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
    static let moveSymbol = "arrow.up.and.down.and.arrow.left.and.right"

    let name = NSTextField(labelWithString: "")
    let move = CapsuleButton(
        "", keys: [], symbol: WidgetEditBar.moveSymbol, height: WidgetEditBar.buttonHeight)
    let remove = NSButton()
    let hintIcon = NSImageView()
    let hint = NSTextField(labelWithString: "")
    let undo = CapsuleButton(
        "Undo", keys: ["⌘", "Z"], symbol: nil, height: WidgetEditBar.undoHeight)
    private let hintStack: NSStackView
    let inspector: GlassView
    let notice: GlassView
    var onMove: (() -> Void)?
    var onRemove: (() -> Void)?
    var onUndo: (() -> Void)?

    init() {
        name.font = .systemFont(ofSize: Self.nameSize, weight: .semibold)
        remove.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        remove.symbolConfiguration = .init(pointSize: Self.removeSize, weight: .medium)
        remove.contentTintColor = .systemRed
        remove.isBordered = false
        remove.refusesFirstResponder = true
        let tools = NSStackView(views: [name, move, FloatingCapsule.divider(), remove])
        tools.setCustomSpacing(Self.nameGap, after: name)
        inspector = FloatingCapsule.make(
            tools, leading: Self.inspectorLeading, trailing: Self.inspectorTrailing)
        hintIcon.symbolConfiguration = .init(pointSize: Self.hintSize, weight: .medium)
        hintIcon.contentTintColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: Self.hintSize, weight: .medium)
        hint.textColor = .secondaryLabelColor
        hint.lineBreakMode = .byTruncatingTail
        hint.setContentCompressionResistancePriority(.defaultHigh + 1, for: .horizontal)
        hintStack = NSStackView(views: [hintIcon, hint, undo])
        hintStack.spacing = Self.hintGap
        notice = FloatingCapsule.make(
            hintStack, leading: Self.hintLeading, trailing: Self.hintTrailing.plain,
            height: Self.hintHeight, radius: Self.hintRadius)
        super.init(frame: .zero)
        remove.target = self
        remove.action = #selector(pressRemove)
        move.onPress = { [weak self] in self?.onMove?() }
        undo.onPress = { [weak self] in self?.onUndo?() }
        move.setAccessibilityLabel("Move to…")
        setViews([inspector, notice], in: .leading)
        spacing = Self.gap
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            remove.widthAnchor.constraint(equalToConstant: Self.buttonHeight),
            remove.heightAnchor.constraint(equalToConstant: Self.buttonHeight),
        ])
        show(nil, moving: false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ widget: (name: String, spot: WidgetGrid.Spot)?, moving: Bool) {
        inspector.isHidden = widget == nil
        guard let widget else { return }
        name.stringValue = widget.name
        move.label.stringValue = widget.spot.title
        move.setAccessibilityValue(widget.spot.title)
        move.fillColor = moving ? .controlAccentColor : .clear
        move.label.textColor = moving ? .white : .labelColor
        move.icon.contentTintColor = move.label.textColor
        remove.setAccessibilityLabel("Remove \(widget.name)")
        setAccessibilityLabel("\(widget.name) options")
    }

    func show(hint text: String?, symbol: String, undoable: Bool) {
        notice.isHidden = text == nil
        hint.stringValue = text ?? ""
        hintIcon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        undo.isHidden = !undoable
        hintStack.edgeInsets.right = undoable ? Self.hintTrailing.undo : Self.hintTrailing.plain
    }

    @objc
    private func pressRemove() {
        onRemove?()
    }
}
