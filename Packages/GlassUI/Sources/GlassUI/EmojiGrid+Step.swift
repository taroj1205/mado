import AppKit

extension EmojiGrid {
    static func step(
        from start: IndexPath, _ direction: Direction, counts: [Int], columns: Int
    ) -> IndexPath? {
        let column = start.item % columns
        switch direction {
        case .left, .right:
            let flat = counts.prefix(start.section).reduce(0, +) + start.item
            return position(of: flat + (direction == .left ? -1 : 1), in: counts)

        case .above where start.item >= columns:
            return IndexPath(item: start.item - columns, section: start.section)

        case .above:
            guard let section = counts[..<start.section].lastIndex(where: { $0 > 0 }) else {
                return nil
            }
            let lastRow = (counts[section] - 1) / columns * columns
            return IndexPath(item: min(lastRow + column, counts[section] - 1), section: section)

        case .below where start.item + columns < counts[start.section]:
            return IndexPath(item: start.item + columns, section: start.section)

        case .below where (start.item / columns + 1) * columns < counts[start.section]:
            return IndexPath(item: counts[start.section] - 1, section: start.section)

        case .below:
            guard
                let section = counts.indices.dropFirst(start.section + 1).first(where: { index in
                    counts[index] > 0
                })
            else { return nil }
            return IndexPath(item: min(column, counts[section] - 1), section: section)
        }
    }

    static func position(of flat: Int, in counts: [Int]) -> IndexPath? {
        guard flat >= 0 else { return nil }
        var remaining = flat
        for (section, count) in counts.enumerated() {
            if remaining < count { return IndexPath(item: remaining, section: section) }
            remaining -= count
        }
        return nil
    }
}
