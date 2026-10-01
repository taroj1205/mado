public import AppKit

public final class LauncherView: NSView, NSTextFieldDelegate {
    private static let searchBarHeight: CGFloat = 60
    private static let searchInset: CGFloat = 20
    private static let searchFontSize: CGFloat = 20
    private static let searchIconGap: CGFloat = 12
    private static let resultsInset: CGFloat = 8
    private static let returnKeys: Set<String?> = ["\r", "\u{3}"]
    private static let modifierKeys: NSEvent.ModifierFlags = [.shift, .control, .option, .command]

    public let field = NSTextField()
    public let results = ResultList()
    public var onQuery: ((String) -> Void)?
    public var onCancel: (() -> Void)?
    public var onRun: ((ResultList.Item, Int) -> Void)?

    override public init(frame: NSRect) {
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override public func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(Self.modifierKeys) == .command,
            Self.returnKeys.contains(event.charactersIgnoringModifiers),
            let editor = field.currentEditor() as? NSTextView, !editor.hasMarkedText()
        else { return super.performKeyEquivalent(with: event) }
        run(1)
        return true
    }

    public func controlTextDidChange(_: Notification) {
        onQuery?(field.stringValue)
    }

    public func control(
        _: NSControl, textView _: NSTextView, doCommandBy selector: Selector
    ) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp): results.selectPrevious()
        case #selector(NSResponder.moveDown): results.selectNext()
        case #selector(NSResponder.insertNewline): run(0)
        case #selector(NSResponder.cancelOperation): onCancel?()
        default: return false
        }
        return true
    }

    private func run(_ action: Int) {
        guard let item = results.selectedItem else { return }
        onRun?(item, action)
    }
}
