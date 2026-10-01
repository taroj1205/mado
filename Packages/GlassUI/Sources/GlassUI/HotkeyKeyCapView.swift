import AppKit

final class HotkeyKeyCapView: NSView {
    private typealias Style = HotkeyRecorderStyle

    init(_ title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = Style.keyCapRadius
        layer?.backgroundColor = Style.keyCapFill.cgColor
        let label = NSTextField(labelWithString: title)
        label.font = Style.keyCapFont
        label.textColor = Style.keyCapText
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Style.keyCapHeight),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Style.keyCapHeight),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Style.keyCapPadding),
            label.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Style.keyCapPadding),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder _: NSCoder) {
        nil
    }
}
