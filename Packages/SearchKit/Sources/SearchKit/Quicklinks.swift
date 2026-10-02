public struct Quicklinks: Codable, Equatable, Sendable {
    public private(set) var links: [Quicklink]

    public init() {
        links = []
    }

    public mutating func update(_ link: Quicklink) {
        if let index = links.firstIndex(where: { $0.id == link.id }) {
            links[index] = link
        } else {
            links.append(link)
        }
    }

    public subscript(id: String) -> Quicklink? {
        links.first { $0.id == id }
    }
}
