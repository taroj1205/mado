public struct RadialSettings: Codable, Equatable, Sendable {
    public enum Action: String, Codable, CaseIterable, Sendable {
        case maximize = "maximize"
        case almostMaximize = "almost_maximize"
        case centre = "centre"
        case fullScreen = "full_screen"
        case topCycle = "top_cycle"
        case rightCycle = "right_cycle"
        case bottomCycle = "bottom_cycle"
        case leftCycle = "left_cycle"
        case topHalf = "top_half"
        case rightHalf = "right_half"
        case bottomHalf = "bottom_half"
        case leftHalf = "left_half"
        case topLeftQuarter = "top_left_quarter"
        case topRightQuarter = "top_right_quarter"
        case bottomLeftQuarter = "bottom_left_quarter"
        case bottomRightQuarter = "bottom_right_quarter"
        case leftThird = "left_third"
        case centreThird = "centre_third"
        case rightThird = "right_third"
        case nothing = "nothing"
    }

    public var ring: Action
    public var top: Action
    public var topRight: Action
    public var right: Action
    public var bottomRight: Action
    public var bottom: Action
    public var bottomLeft: Action
    public var left: Action
    public var topLeft: Action
    public var haptics: Bool

    public init() {
        ring = .maximize
        top = .topCycle
        topRight = .topRightQuarter
        right = .rightCycle
        bottomRight = .bottomRightQuarter
        bottom = .bottomCycle
        bottomLeft = .bottomLeftQuarter
        left = .leftCycle
        topLeft = .topLeftQuarter
        haptics = true
    }
}
