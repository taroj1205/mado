public import AppCore
public import AppKit

public final class TapKeyboard: NSStackView {
    private struct Key {
        let symbol: String
        let word: String
        let width: CGFloat
        let modifier: HotKey.ModifierKey?
        var showsOnlyWhenBound = false
    }

    private static let narrow: CGFloat = 40
    private static let wide: CGFloat = 70
    private static let space: CGFloat = 200
    private static let keys = [
        Key(
            symbol: "⇧", word: "shift", width: wide, modifier: .leftShift,
            showsOnlyWhenBound: true),
        Key(symbol: "fn", word: "globe", width: narrow, modifier: nil),
        Key(symbol: "⌃", word: "control", width: narrow, modifier: .leftControl),
        Key(symbol: "⌥", word: "option", width: narrow, modifier: .leftOption),
        Key(symbol: "⌘", word: "command", width: wide, modifier: .leftCommand),
        Key(symbol: "", word: "", width: space, modifier: nil),
        Key(symbol: "⌘", word: "command", width: wide, modifier: .rightCommand),
        Key(symbol: "⌥", word: "option", width: narrow, modifier: .rightOption),
        Key(
            symbol: "⌃", word: "control", width: narrow, modifier: .rightControl,
            showsOnlyWhenBound: true),
        Key(
            symbol: "⇧", word: "shift", width: wide, modifier: .rightShift,
            showsOnlyWhenBound: true),
    ]
    private static let keyHeight: CGFloat = 42
    private static let keyRadius: CGFloat = 8
    private static let keyGap: CGFloat = 5
    private static let chipGap: CGFloat = 7
    private static let chipHeight: CGFloat = 20
    private static let chipRadius: CGFloat = 10
    private static let chipInset: CGFloat = 8
    private static let chipMaxWidth: CGFloat = 72
    private static let symbolSize: CGFloat = 13
    private static let wordSize: CGFloat = 9
    private static let chipSize: CGFloat = 11.5
    private static let labelInset: CGFloat = 7
    private static let labelTop: CGFloat = 5
    private static let boundAlpha: CGFloat = 0.14
    private static let idleAlpha: CGFloat = 0.07

    public init() {
        super.init(frame: .zero)
        alignment = .top
        spacing = Self.keyGap
        show([:])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    public func show(_ labels: [HotKey.ModifierKey: String]) {
        let shown = Self.keys.filter { key in
            !key.showsOnlyWhenBound || key.modifier.flatMap { labels[$0] } != nil
        }
        setViews(
            shown.map { key in
                let label = key.modifier.flatMap { labels[$0] }
                let column = NSStackView(views: [cap(key, bound: label != nil), chip(label)])
                column.orientation = .vertical
                column.alignment = .centerX
                column.spacing = Self.chipGap
                if let modifier = key.modifier, let label {
                    let name = HotKeyLabel.keycaps(.modifierTap(modifier)).joined()
                    column.setAccessibilityElement(true)
                    column.setAccessibilityRole(.group)
                    column.setAccessibilityLabel("\(name) tap: \(label)")
                }
                return column
            }, in: .center)
    }

    private func cap(_ key: Key, bound: Bool) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = Self.keyRadius
        box.borderColor = .separatorColor
        box.fillColor = .labelColor.withAlphaComponent(bound ? Self.boundAlpha : Self.idleAlpha)
        box.contentViewMargins = .zero
        let symbol = NSTextField(labelWithString: key.symbol)
        symbol.font = .systemFont(ofSize: Self.symbolSize)
        symbol.textColor = bound ? .labelColor : .tertiaryLabelColor
        let word = NSTextField(labelWithString: key.word)
        word.font = .systemFont(ofSize: Self.wordSize)
        word.textColor = bound ? .secondaryLabelColor : .tertiaryLabelColor
        for label in [symbol, word] {
            label.translatesAutoresizingMaskIntoConstraints = false
            box.addSubview(label)
        }
        NSLayoutConstraint.activate([
            box.widthAnchor.constraint(equalToConstant: key.width),
            box.heightAnchor.constraint(equalToConstant: Self.keyHeight),
            symbol.topAnchor.constraint(equalTo: box.topAnchor, constant: Self.labelTop),
            symbol.trailingAnchor.constraint(
                equalTo: box.trailingAnchor, constant: -Self.labelInset),
            word.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -Self.labelTop),
            word.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Self.labelInset),
        ])
        box.setAccessibilityElement(false)
        return box
    }

    private func chip(_ label: String?) -> NSView {
        let text = NSTextField(labelWithString: label ?? "")
        text.font = .systemFont(ofSize: Self.chipSize, weight: .semibold)
        text.textColor = .white
        text.lineBreakMode = .byTruncatingTail
        text.widthAnchor.constraint(lessThanOrEqualToConstant: Self.chipMaxWidth).isActive = true
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = Self.chipRadius
        box.fillColor = .controlAccentColor
        box.contentViewMargins = .zero
        text.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(text)
        box.isHidden = label == nil
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: Self.chipHeight),
            text.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: Self.chipInset),
            text.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -Self.chipInset),
            text.centerYAnchor.constraint(equalTo: box.centerYAnchor),
        ])
        return box
    }
}
