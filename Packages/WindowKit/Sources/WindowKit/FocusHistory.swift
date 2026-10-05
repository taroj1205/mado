public import CoreGraphics

public struct FocusHistory {
    private var numbers: [CGWindowID]

    public init() {
        numbers = []
    }

    public mutating func focused(_ number: CGWindowID) {
        numbers.removeAll { $0 == number }
        numbers.insert(number, at: 0)
    }

    public mutating func ordered(_ windows: [WindowList.Window]) -> [WindowList.Window] {
        let listed = Set(windows.compactMap(\.number))
        numbers.removeAll { !listed.contains($0) }
        let ranks = Dictionary(uniqueKeysWithValues: numbers.enumerated().map { ($1, $0) })
        let rank = { (index: Int) in
            (windows[index].number.flatMap { ranks[$0] } ?? ranks.count, index)
        }
        return windows.indices.sorted { rank($0) < rank($1) }.map { windows[$0] }
    }
}
