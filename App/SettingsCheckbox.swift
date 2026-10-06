import AppKit

final class SettingsCheckbox: NSButton {
    private let read: () -> Bool
    private let write: (Bool) -> Void

    init(_ title: String, read: @escaping () -> Bool, write: @escaping (Bool) -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero)
        setButtonType(.switch)
        self.title = title
        target = self
        action = #selector(changed)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func refresh() {
        state = read() ? .on : .off
    }

    @objc
    private func changed() {
        write(state == .on)
        refresh()
    }
}
