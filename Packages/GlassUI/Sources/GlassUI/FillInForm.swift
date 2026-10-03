public import AppKit

public final class FillInForm: NSView, NSTextFieldDelegate {
    final class Rows: NSStackView {
        override var isFlipped: Bool { true }
    }

    public struct Field: Equatable, Sendable {
        public let name: String
        public let options: [String]

        public init(name: String, options: [String]) {
            self.name = name
            self.options = options
        }
    }

    public struct Preview: Sendable {
        public let text: String
        public let values: [NSRange]

        public init(text: String, values: [NSRange]) {
            self.text = text
            self.values = values
        }
    }

    public static let width: CGFloat = 420
    static let insetSide: CGFloat = 16
    private static let popUpWidth: CGFloat = 160
    private static let previewSize: CGFloat = 12.5
    private static let previewLine: CGFloat = 1.55
    private static let previewCharacters = 2_000
    private static let buttonSize: CGFloat = 13
    private static let buttonHeight: CGFloat = 26

    public var onInsert: (([String: String]) -> Void)?
    public var onCancel: (() -> Void)?
    public var preview: ([String: String]) -> Preview = { _ in Preview(text: "", values: []) }
    public var maxHeight: CGFloat? {
        didSet {
            heightLimit.constant = maxHeight ?? 0
            heightLimit.isActive = maxHeight != nil
        }
    }

    let title = NSTextField(labelWithString: "")
    let subtitle = NSTextField(labelWithString: "")
    let rows = Rows()
    let previewText = NSTextField(wrappingLabelWithString: "")
    let cancel = ChipButton(
        font: .systemFont(ofSize: FillInForm.buttonSize, weight: .medium),
        height: FillInForm.buttonHeight, symbol: nil)
    let insert = PillButton("Insert", height: FillInForm.buttonHeight)
    private(set) var controls: [(name: String, control: NSControl)] = []
    private lazy var heightLimit = heightAnchor.constraint(lessThanOrEqualToConstant: 0)
    private var focusWatch: NSKeyValueObservation?

    override public var acceptsFirstResponder: Bool { true }

    public var values: [String: String] {
        let pairs = controls.map { name, control in
            (name, (control as? NSPopUpButton)?.titleOfSelectedItem ?? control.stringValue)
        }
        return Dictionary(pairs) { first, _ in first }
    }

    override public init(frame: NSRect) {
        super.init(frame: frame)
        cancel.title = "Cancel"
        cancel.onPress = { [weak self] in self?.onCancel?() }
        insert.target = self
        insert.action = #selector(insertValues)
        layoutForm()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(name: String, keyword: String, fields: [Field]) {
        title.stringValue = name
        subtitle.stringValue = "Snippet · keyword \(keyword)"
        controls = fields.map { field in (field.name, control(for: field)) }
        rows.setViews(controls.map { row($0.name, $0.control) }, in: .top)
        for row in rows.views {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        let loop = controls.map(\.control)
        for (control, next) in zip(loop, loop.dropFirst() + loop.prefix(1)) {
            unsafe control.nextKeyView = next
        }
        showPreview()
    }

    public func focus() {
        unsafe window?.makeFirstResponder(controls.first?.control ?? self)
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        focusWatch = unsafe window?.observe(\.firstResponder) { [weak self] window, _ in
            MainActor.assumeIsolated { self?.reveal(window.firstResponder) }
        }
    }

    override public func keyDown(with event: NSEvent) {
        interpretKeyEvents([event])
    }

    override public func insertNewline(_: Any?) {
        insertValues()
    }

    override public func cancelOperation(_: Any?) {
        onCancel?()
    }

    public func controlTextDidChange(_: Notification) {
        showPreview()
    }

    public func control(
        _: NSControl, textView: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline) where textView.hasMarkedText(): return false
        case #selector(NSResponder.insertNewline): insertValues()
        case #selector(NSResponder.cancelOperation): onCancel?()
        default: return false
        }
        return true
    }

    @objc
    private func insertValues() {
        onInsert?(values)
    }

    @objc
    private func showPreview() {
        let shown = preview(values)
        let visible = String(shown.text.prefix(Self.previewCharacters))
        let length = visible.utf16.count
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Self.previewLine
        let text = NSMutableAttributedString(
            string: visible,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.previewSize),
                .foregroundColor: NSColor.labelColor, .paragraphStyle: style,
            ])
        for range in shown.values where range.location < length {
            text.addAttribute(
                .font, value: NSFont.boldSystemFont(ofSize: Self.previewSize),
                range: NSRange(
                    location: range.location, length: min(range.length, length - range.location)))
        }
        previewText.attributedStringValue = text
        previewText.setAccessibilityLabel("Preview: \(visible)")
        fitWindow()
    }

    private func reveal(_ responder: NSResponder?) {
        guard let view = responder as? NSView,
            let control = controls.first(where: { view.isDescendant(of: $0.control) })?.control
        else { return }
        control.scrollToVisible(control.bounds)
    }

    private func fitWindow() {
        guard let window = unsafe window else { return }
        let size = fittingSize
        var frame = window.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        if let visible = window.screen?.visibleFrame {
            frame.origin.y = max(frame.minY, visible.minY)
        }
        window.setFrame(frame, display: true)
    }

    private func control(for field: Field) -> NSControl {
        guard field.options.isEmpty else {
            let popUp = NSPopUpButton(frame: .zero, pullsDown: false)
            popUp.addItems(withTitles: field.options)
            popUp.font = SheetForm.font
            popUp.setAccessibilityLabel(field.name)
            popUp.target = self
            popUp.action = #selector(showPreview)
            popUp.widthAnchor.constraint(equalToConstant: Self.popUpWidth).isActive = true
            return popUp
        }
        let input = NSTextField()
        input.delegate = self
        input.setAccessibilityLabel(field.name)
        return input
    }
}
