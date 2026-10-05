extension RadialSettings {
    public func label(in zone: RadialResolver.Zone, step: Int) -> String {
        let action = action(in: zone)
        if action == .fullScreen { return "macOS Full Screen" }
        return action.layout(step: step)?.label ?? "Cancel"
    }
}

extension LayoutEngine.Action {
    var label: String {
        switch self {
        case .almostMaximize: "Almost Maximize"
        case .bottomHalf: "Bottom Half"
        case .bottomLeftQuarter: "Bottom Left Quarter"
        case .bottomRightQuarter: "Bottom Right Quarter"
        case .bottomThird: "Bottom Third"
        case .bottomTwoThirds: "Bottom Two Thirds"
        case .centre: "Centre"
        case .centreThird: "Centre Third"
        case .leftHalf: "Left Half"
        case .leftThird: "Left Third"
        case .leftTwoThirds: "Left Two Thirds"
        case .maximize: "Maximize"
        case .rightHalf: "Right Half"
        case .rightThird: "Right Third"
        case .rightTwoThirds: "Right Two Thirds"
        case .topHalf: "Top Half"
        case .topLeftQuarter: "Top Left Quarter"
        case .topRightQuarter: "Top Right Quarter"
        case .topThird: "Top Third"
        case .topTwoThirds: "Top Two Thirds"
        }
    }
}
