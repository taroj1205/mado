public import CoreGraphics

extension RadialSettings {
    public static let groups: [(title: String, actions: [Action])] = [
        ("Fill", [.maximize, .almostMaximize, .centre, .fullScreen]),
        ("Cycles", [.topCycle, .rightCycle, .bottomCycle, .leftCycle]),
        ("Halves", [.topHalf, .rightHalf, .bottomHalf, .leftHalf]),
        ("Quarters", [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]),
        ("Thirds", [.leftThird, .centreThird, .rightThird]),
        ("Other", [.nothing]),
    ]
}

extension RadialSettings.Action {
    private static let half: CGFloat = 0.5
    private static let thirds: CGFloat = 3
    private static let third = 1 / thirds
    private static let twoThirds = 1 - third
    private static let almostInset: (x: CGFloat, y: CGFloat) = (0.07, 0.08)
    private static let centreInset: (x: CGFloat, y: CGFloat) = (0.22, 0.2)
    private static let cycle = "½ → ⅓ → ⅔"

    public var title: String {
        switch self {
        case .maximize: "Maximize"
        case .almostMaximize: "Almost maximize"
        case .centre: "Centre"
        case .fullScreen: "macOS full screen"
        case .topCycle: "Top cycle"
        case .rightCycle: "Right cycle"
        case .bottomCycle: "Bottom cycle"
        case .leftCycle: "Left cycle"
        case .topHalf: "Top half"
        case .rightHalf: "Right half"
        case .bottomHalf: "Bottom half"
        case .leftHalf: "Left half"
        case .topLeftQuarter: "Top left quarter"
        case .topRightQuarter: "Top right quarter"
        case .bottomLeftQuarter: "Bottom left quarter"
        case .bottomRightQuarter: "Bottom right quarter"
        case .leftThird: "Left third"
        case .centreThird: "Centre third"
        case .rightThird: "Right third"
        case .nothing: "Nothing"
        }
    }

    public var detail: String? {
        switch self {
        case .nothing: "ignored"
        case _ where isCycle: Self.cycle
        default: nil
        }
    }

    public var isCycle: Bool {
        [.topCycle, .rightCycle, .bottomCycle, .leftCycle].contains(self)
    }

    public var glyph: CGRect {
        switch self {
        case .maximize, .fullScreen: CGRect(x: 0, y: 0, width: 1, height: 1)
        case .almostMaximize: Self.inset(Self.almostInset)
        case .centre: Self.inset(Self.centreInset)
        case .topCycle, .topHalf: CGRect(x: 0, y: 0, width: 1, height: Self.half)
        case .rightCycle, .rightHalf: CGRect(x: Self.half, y: 0, width: Self.half, height: 1)
        case .bottomCycle, .bottomHalf: CGRect(x: 0, y: Self.half, width: 1, height: Self.half)
        case .leftCycle, .leftHalf: CGRect(x: 0, y: 0, width: Self.half, height: 1)
        case .topLeftQuarter: Self.quarter(left: 0, top: 0)
        case .topRightQuarter: Self.quarter(left: Self.half, top: 0)
        case .bottomLeftQuarter: Self.quarter(left: 0, top: Self.half)
        case .bottomRightQuarter: Self.quarter(left: Self.half, top: Self.half)
        case .leftThird: CGRect(x: 0, y: 0, width: Self.third, height: 1)
        case .centreThird: CGRect(x: Self.third, y: 0, width: Self.third, height: 1)
        case .rightThird: CGRect(x: Self.twoThirds, y: 0, width: Self.third, height: 1)
        case .nothing: .zero
        }
    }

    private static func quarter(left: CGFloat, top: CGFloat) -> CGRect {
        CGRect(x: left, y: top, width: half, height: half)
    }

    private static func inset(_ inset: (x: CGFloat, y: CGFloat)) -> CGRect {
        CGRect(x: 0, y: 0, width: 1, height: 1).insetBy(dx: inset.x, dy: inset.y)
    }
}
