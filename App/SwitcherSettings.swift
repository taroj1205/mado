struct SwitcherSettings: StoredValue, Equatable {
    enum Order: String, Codable, CaseIterable {
        case byApp = "by_app"
        case recent = "recent"

        var title: String {
            switch self {
            case .byApp: "Grouped by App"
            case .recent: "Most Recent Window"
            }
        }
    }

    static let key = "switcher"

    var order: Order

    init() {
        order = .byApp
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        order = try values.decodeIfPresent(Order.self, forKey: .order) ?? order
    }
}
