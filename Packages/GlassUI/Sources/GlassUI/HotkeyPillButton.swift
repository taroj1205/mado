import AppKit

final class HotkeyPillButton: NSButton {
    private typealias Style = HotkeyRecorderStyle

    private let handler: () -> Void

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: super.intrinsicContentSize.width + Style.pillHorizontalPadding,
            height: Style.pillHeight)
    }

    init(title: String, filled: Bool, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = Style.pillRadius
        layer?.backgroundColor = (filled ? Style.blue : Style.pillFill).cgColor
        attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: Style.pillFont,
                .foregroundColor: filled ? NSColor.white : Style.keyCapText,
            ])
        target = self
        action = #selector(fire)
        heightAnchor.constraint(equalToConstant: Style.pillHeight).isActive = true
    }

    required init?(coder _: NSCoder) {
        nil
    }

    @objc private func fire() {
        handler()
    }
}
