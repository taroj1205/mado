import CoreGraphics

struct LayoutSettings: StoredValue, Equatable {
    static let key = "layouts"
    private static let gapStep: CGFloat = 4
    private static let largestGap: CGFloat = 24
    private static let defaultGap: CGFloat = 8
    static let gaps = Array(stride(from: 0, through: largestGap, by: gapStep))

    var gap: CGFloat
    var assignedDefaultHotKeys: Bool

    init() {
        gap = Self.defaultGap
        assignedDefaultHotKeys = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        gap = try values.decodeIfPresent(CGFloat.self, forKey: .gap) ?? gap
        assignedDefaultHotKeys =
            try values.decodeIfPresent(Bool.self, forKey: .assignedDefaultHotKeys)
            ?? assignedDefaultHotKeys
    }
}
