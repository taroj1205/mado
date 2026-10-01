import AppCore
import AppKit
import os

final class SettingsPopUp: NSPopUpButton {
    private let logger = Log.logger("Settings")
    private let read: () -> Int
    private let write: (Int) throws -> Void

    init(_ titles: [String], read: @escaping () -> Int, write: @escaping (Int) throws -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero, pullsDown: false)
        addItems(withTitles: titles)
        target = self
        action = #selector(changed)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func refresh() {
        selectItem(at: read())
    }

    @objc
    private func changed() {
        do {
            try write(indexOfSelectedItem)
        } catch {
            let name = accessibilityLabel() ?? ""
            logger.error("\(name, privacy: .public) failed: \(error, privacy: .public)")
            presentError(error)
        }
        refresh()
    }
}
