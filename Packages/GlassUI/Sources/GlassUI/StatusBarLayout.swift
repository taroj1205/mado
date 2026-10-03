public struct StatusBarLayout: Codable, Equatable, Sendable {
    private(set) var shown: [String]
    private(set) var hidden: [String]

    public init() {
        shown = []
        hidden = []
    }

    func arrange(_ pills: [StatusBar.Pill]) -> [StatusBar.Pill] {
        order(of: pills).compactMap { id in pills.first { $0.id == id } }
    }

    mutating func show(_ id: String, _ isShown: Bool, among pills: [StatusBar.Pill]) {
        let order = order(of: pills)
        guard order.contains(id) != isShown else { return }
        shown = order.filter { $0 != id }
        hidden.removeAll { $0 == id }
        if isShown {
            shown.append(id)
        } else {
            hidden.append(id)
        }
    }

    mutating func move(_ id: String, before target: String?, among pills: [StatusBar.Pill]) {
        var order = order(of: pills)
        guard id != target, let from = order.firstIndex(of: id) else { return }
        order.remove(at: from)
        let index = target.flatMap { order.firstIndex(of: $0) } ?? order.endIndex
        order.insert(id, at: index)
        shown = order
    }

    private func order(of pills: [StatusBar.Pill]) -> [String] {
        let unchosen = pills.filter { pill in
            pill.shownByDefault && !shown.contains(pill.id) && !hidden.contains(pill.id)
        }
        return shown + unchosen.map(\.id)
    }
}
