public import AppCore
public import CoreGraphics

public struct RadialSettings: Codable, Equatable, Sendable {
    public enum Origin: String, Codable, CaseIterable, Sendable {
        case pointer = "pointer"
        case screenCentre = "screen_centre"
    }

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

        private static let layouts: [Self: LayoutEngine.Action] = [
            .maximize: .maximize, .almostMaximize: .almostMaximize, .centre: .centre,
            .topCycle: .topHalf, .rightCycle: .rightHalf, .bottomCycle: .bottomHalf,
            .leftCycle: .leftHalf, .topHalf: .topHalf, .rightHalf: .rightHalf,
            .bottomHalf: .bottomHalf, .leftHalf: .leftHalf, .topLeftQuarter: .topLeftQuarter,
            .topRightQuarter: .topRightQuarter, .bottomLeftQuarter: .bottomLeftQuarter,
            .bottomRightQuarter: .bottomRightQuarter, .leftThird: .leftThird,
            .centreThird: .centreThird, .rightThird: .rightThird,
        ]

        public var half: HalfSnap.Side? {
            switch self {
            case .leftHalf, .leftCycle: .left
            case .rightHalf, .rightCycle: .right
            default: nil
            }
        }

        public func previewFrame(
            of window: CGRect, on screen: ScreenGeometry.Screen, gap: CGFloat
        ) -> CGRect? {
            if self == .fullScreen { return screen.frame }
            guard let layout = Self.layouts[self] else { return nil }
            return LayoutEngine.frame(
                for: layout, in: screen.visibleFrame, gap: gap, windowSize: window.size)
        }

        public func quartzFrame(
            forQuartz window: CGRect, across screens: [ScreenGeometry.Screen]
        ) -> CGRect? {
            guard let primary = screens.first?.frame,
                let index = ScreenGeometry.screenIndex(showing: window, in: screens.map(\.frame)),
                let target = previewFrame(
                    of: ScreenGeometry.appKitRect(fromQuartz: window, primary: primary),
                    on: screens[index], gap: 0)
            else { return nil }
            return ScreenGeometry.quartzRect(fromAppKit: target, primary: primary)
        }
    }

    private static let slots: [RadialResolver.Direction: any KeyPath<Self, Action> & Sendable] = [
        .top: \.top, .topRight: \.topRight, .right: \.right, .bottomRight: \.bottomRight,
        .bottom: \.bottom, .bottomLeft: \.bottomLeft, .left: \.left, .topLeft: \.topLeft,
    ]

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
    public var isEnabled: Bool
    public var trigger: Shortcut.Modifiers
    public var opensAt: Origin
    public var showsPreview: Bool
    public var showsLabel: Bool
    public var clickStepsCycle: Bool

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
        isEnabled = true
        trigger = [.function]
        opensAt = .pointer
        showsPreview = true
        showsLabel = false
        clickStepsCycle = true
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        ring = try values.decodeIfPresent(Action.self, forKey: .ring) ?? ring
        top = try values.decodeIfPresent(Action.self, forKey: .top) ?? top
        topRight = try values.decodeIfPresent(Action.self, forKey: .topRight) ?? topRight
        right = try values.decodeIfPresent(Action.self, forKey: .right) ?? right
        bottomRight = try values.decodeIfPresent(Action.self, forKey: .bottomRight) ?? bottomRight
        bottom = try values.decodeIfPresent(Action.self, forKey: .bottom) ?? bottom
        bottomLeft = try values.decodeIfPresent(Action.self, forKey: .bottomLeft) ?? bottomLeft
        left = try values.decodeIfPresent(Action.self, forKey: .left) ?? left
        topLeft = try values.decodeIfPresent(Action.self, forKey: .topLeft) ?? topLeft
        haptics = try values.decodeIfPresent(Bool.self, forKey: .haptics) ?? haptics
        isEnabled = try values.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? isEnabled
        trigger = try values.decodeIfPresent(Shortcut.Modifiers.self, forKey: .trigger) ?? trigger
        opensAt = try values.decodeIfPresent(Origin.self, forKey: .opensAt) ?? opensAt
        showsPreview = try values.decodeIfPresent(Bool.self, forKey: .showsPreview) ?? showsPreview
        showsLabel = try values.decodeIfPresent(Bool.self, forKey: .showsLabel) ?? showsLabel
        clickStepsCycle =
            try values.decodeIfPresent(Bool.self, forKey: .clickStepsCycle) ?? clickStepsCycle
    }

    public func action(in zone: RadialResolver.Zone) -> Action {
        switch zone {
        case .cancel: .nothing
        case .ring: ring
        case .direction(let direction): Self.slots[direction].map { self[keyPath: $0] } ?? .nothing
        }
    }
}
