import AppKit

final class SettingsTextField: NSTextField {
    private static let width: CGFloat = 180

    private let write: (String) -> Void

    init(placeholder: String, read: () -> String, write: @escaping (String) -> Void) {
        self.write = write
        super.init(frame: .zero)
        stringValue = read()
        placeholderString = placeholder
        widthAnchor.constraint(equalToConstant: Self.width).isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func textDidChange(_ notification: Notification) {
        super.textDidChange(notification)
        write(stringValue)
    }
}
