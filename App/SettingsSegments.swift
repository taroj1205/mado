import AppKit

final class SettingsSegments: NSSegmentedControl {
    private let read: () -> Int
    private let write: (Int) -> Void

    init(_ titles: [String], read: @escaping () -> Int, write: @escaping (Int) -> Void) {
        self.read = read
        self.write = write
        super.init(frame: .zero)
        segmentCount = titles.count
        for (index, title) in titles.enumerated() {
            setLabel(title, forSegment: index)
        }
        trackingMode = .selectOne
        target = self
        action = #selector(changed)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
        refresh()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func refresh() {
        selectedSegment = read()
    }

    @objc
    private func changed() {
        write(selectedSegment)
        refresh()
    }
}
