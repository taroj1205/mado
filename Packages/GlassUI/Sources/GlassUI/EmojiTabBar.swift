import AppKit

final class EmojiTabBar: NSStackView {
    private static let width: CGFloat = 34
    private static let height: CGFloat = 30
    private static let symbolSize: CGFloat = 13
    private static let gap: CGFloat = 2

    var onPress: ((Int) -> Void)?
    private var buttons: [EmojiTab] = []

    init() {
        super.init(frame: .zero)
        spacing = Self.gap
        setAccessibilityRole(.tabGroup)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ tabs: [EmojiGrid.Tab]) {
        buttons = tabs.enumerated().map { index, tab in
            let button = EmojiTab(
                image: NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
                    ?? NSImage(),
                target: self, action: #selector(pressed))
            button.tag = index
            button.isBordered = false
            button.wantsLayer = true
            button.symbolConfiguration = .init(pointSize: Self.symbolSize, weight: .semibold)
            button.refusesFirstResponder = true
            button.toolTip = tab.title
            button.setAccessibilityRole(.radioButton)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: Self.width),
                button.heightAnchor.constraint(equalToConstant: Self.height),
            ])
            return button
        }
        setViews(buttons, in: .leading)
        highlight(nil)
    }

    func highlight(_ index: Int?) {
        for button in buttons {
            button.isOn = button.tag == index
        }
    }

    @objc
    private func pressed(_ sender: NSButton) {
        onPress?(sender.tag)
    }
}
