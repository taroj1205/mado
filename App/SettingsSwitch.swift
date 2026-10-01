import AppCore
import AppKit
import os

final class SettingsSwitch: NSSwitch {
    private let logger = Log.logger("Settings")
    private let read: () -> Bool
    private let write: (Bool) throws -> Void

    init(read: @escaping () -> Bool, write: @escaping (Bool) throws -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero)
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
        do {
            try write(state == .on)
        } catch {
            let name = accessibilityLabel() ?? ""
            logger.error("\(name, privacy: .public) failed: \(error, privacy: .public)")
            presentError(error)
        }
        refresh()
    }
}
