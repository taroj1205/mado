import Carbon.HIToolbox
import IOKit.hidsystem

public enum ModifierKey: Hashable, Sendable, CaseIterable {
    case leftCommand
    case leftControl
    case leftOption
    case leftShift
    case rightCommand
    case rightControl
    case rightOption
    case rightShift

    private struct Info {
        let keyCode: Int
        let deviceMask: Int
        let symbol: String
        let side: String
    }

    public var deviceMask: UInt { UInt(info.deviceMask) }

    public var symbol: String { info.symbol }

    public var label: String { "\(info.side) \(info.symbol)" }

    private var info: Info {
        switch self {
        case .leftCommand:
            Info(
                keyCode: kVK_Command, deviceMask: Int(NX_DEVICELCMDKEYMASK), symbol: "⌘",
                side: "Left")

        case .leftControl:
            Info(
                keyCode: kVK_Control, deviceMask: Int(NX_DEVICELCTLKEYMASK), symbol: "⌃",
                side: "Left")

        case .leftOption:
            Info(
                keyCode: kVK_Option, deviceMask: Int(NX_DEVICELALTKEYMASK), symbol: "⌥",
                side: "Left")

        case .leftShift:
            Info(
                keyCode: kVK_Shift, deviceMask: Int(NX_DEVICELSHIFTKEYMASK), symbol: "⇧",
                side: "Left")

        case .rightCommand:
            Info(
                keyCode: kVK_RightCommand, deviceMask: Int(NX_DEVICERCMDKEYMASK), symbol: "⌘",
                side: "Right")

        case .rightControl:
            Info(
                keyCode: kVK_RightControl, deviceMask: Int(NX_DEVICERCTLKEYMASK), symbol: "⌃",
                side: "Right")

        case .rightOption:
            Info(
                keyCode: kVK_RightOption, deviceMask: Int(NX_DEVICERALTKEYMASK), symbol: "⌥",
                side: "Right")

        case .rightShift:
            Info(
                keyCode: kVK_RightShift, deviceMask: Int(NX_DEVICERSHIFTKEYMASK), symbol: "⇧",
                side: "Right")
        }
    }

    public init?(keyCode: UInt16) {
        guard let key = Self.allCases.first(where: { $0.info.keyCode == Int(keyCode) }) else {
            return nil
        }
        self = key
    }
}
