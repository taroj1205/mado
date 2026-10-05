import AppKit

final class WidgetEditBar: NSStackView {
    private static let titleSize: CGFloat = 17
    private static let buttonHeight: CGFloat = 26
    private static let gap: CGFloat = 12

    let title = NSTextField(labelWithString: "Editing widgets")
    let add = PillButton(
        "Add Widget", height: buttonHeight, symbol: "plus", fill: FloatingCapsule.keycapFill,
        text: .labelColor)
    let done = PillButton("Done", height: buttonHeight)
    var onAdd: (() -> Void)?
    var onDone: (() -> Void)?
    var onRemove: (() -> Void)?
    var onStep: ((WidgetGrid.Heading) -> Void)?
    var onSend: ((WidgetGrid.Heading) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        for (button, action) in [(add, #selector(pressAdd)), (done, #selector(pressDone))] {
            button.refusesFirstResponder = true
            button.target = self
            button.action = action
        }
        [title, add, done].forEach(addArrangedSubview)
        distribution = .fill
        spacing = Self.gap
        translatesAutoresizingMaskIntoConstraints = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func heading(of event: NSEvent) -> WidgetGrid.Heading? {
        switch event.specialKey {
        case .upArrow: .top
        case .downArrow: .bottom
        case .leftArrow: .left
        case .rightArrow: .right
        default: nil
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.option), let heading = Self.heading(of: event) {
            onSend?(heading)
            return
        }
        interpretKeyEvents([event])
    }

    override func deleteBackward(_: Any?) {
        onRemove?()
    }

    override func deleteForward(_: Any?) {
        onRemove?()
    }

    override func moveLeft(_: Any?) {
        onStep?(.left)
    }

    override func moveRight(_: Any?) {
        onStep?(.right)
    }

    override func moveUp(_: Any?) {
        onStep?(.top)
    }

    override func moveDown(_: Any?) {
        onStep?(.bottom)
    }

    override func insertNewline(_: Any?) {
        onDone?()
    }

    override func cancelOperation(_: Any?) {
        onDone?()
    }

    @objc
    private func pressAdd() {
        onAdd?()
    }

    @objc
    private func pressDone() {
        onDone?()
    }
}
