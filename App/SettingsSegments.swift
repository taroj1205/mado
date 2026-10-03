import AppCore
import AppKit
import os

final class SettingsSegments: NSSegmentedControl {
    private let logger = Log.logger("Settings")
    private let read: () -> Int
    private let write: (Int) throws -> Void

    init(_ labels: [String], read: @escaping () -> Int, write: @escaping (Int) throws -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero)
        segmentCount = labels.count
        for (index, label) in labels.enumerated() {
            setLabel(label, forSegment: index)
        }
        trackingMode = .selectOne
        target = self
        action = #selector(changed)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func refresh() {
        selectedSegment = read()
    }

    @objc
    private func changed() {
        do {
            try write(selectedSegment)
        } catch {
            let name = accessibilityLabel() ?? ""
            logger.error("\(name, privacy: .public) failed: \(error, privacy: .public)")
            presentError(error)
        }
        refresh()
    }
}
