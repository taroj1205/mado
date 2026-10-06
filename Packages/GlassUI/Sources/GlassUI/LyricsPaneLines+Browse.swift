import AppKit

extension LyricsPaneLines {
    var copied: String? {
        switch mode {
        case .synced:
            focus.map { lines[$0] }.flatMap { $0.isEmpty ? nil : $0 }

        case .plain:
            lines.isEmpty ? nil : lines.joined(separator: "\n")
        }
    }

    func browse(by step: Int) {
        guard !rows.isEmpty else { return }
        switch mode {
        case .synced:
            let start = focus ?? (step > 0 ? -1 : rows.count)
            browsed = min(max(start + step, 0), rows.count - 1)
            followLater()

        case .plain:
            offset = clamped(offset + CGFloat(step) * Self.pitch)
        }
        place(animated: true)
    }

    @discardableResult
    func follow() -> Bool {
        resume?.cancel()
        resume = nil
        guard browsed != nil else { return false }
        browsed = nil
        place(animated: true)
        return true
    }

    private func followLater() {
        resume?.cancel()
        resume = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.followSeconds))
            guard !Task.isCancelled else { return }
            self?.follow()
        }
    }
}
