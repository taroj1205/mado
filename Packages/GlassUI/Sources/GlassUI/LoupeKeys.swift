import Carbon.HIToolbox

public struct LoupeKeys: Codable, Equatable, Sendable {
    public enum Direction: CaseIterable, Sendable {
        case top
        case left
        case bottom
        case right

        public var title: String {
            switch self {
            case .top: "Up"
            case .left: "Left"
            case .bottom: "Down"
            case .right: "Right"
            }
        }

        public var glyph: String {
            switch self {
            case .top: "↑"
            case .left: "←"
            case .bottom: "↓"
            case .right: "→"
            }
        }

        var arrowKey: Int {
            switch self {
            case .top: kVK_UpArrow
            case .left: kVK_LeftArrow
            case .bottom: kVK_DownArrow
            case .right: kVK_RightArrow
            }
        }

        var input: ColourLoupe.Input {
            switch self {
            case .top: .nudged(across: 0, down: -1)
            case .left: .nudged(across: -1, down: 0)
            case .bottom: .nudged(across: 0, down: 1)
            case .right: .nudged(across: 1, down: 0)
            }
        }
    }

    public enum Preset: CaseIterable, Sendable {
        case arrows
        case vim
        case wasd
        case ijkl

        public var title: String {
            switch self {
            case .arrows: "Arrows only"
            case .vim: "Vim keys (HJKL)"
            case .wasd: "WASD"
            case .ijkl: "IJKL"
            }
        }

        var letters: [Int] {
            switch self {
            case .arrows: Direction.allCases.map(\.arrowKey)
            case .vim: [kVK_ANSI_K, kVK_ANSI_H, kVK_ANSI_J, kVK_ANSI_L]
            case .wasd: [kVK_ANSI_W, kVK_ANSI_A, kVK_ANSI_S, kVK_ANSI_D]
            case .ijkl: [kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L]
            }
        }

        var hint: String {
            switch self {
            case .arrows: "arrow keys"
            case .vim: "arrows or HJKL"
            case .wasd: "arrows or WASD"
            case .ijkl: "arrows or IJKL"
            }
        }
    }

    private static let refusals = [
        kVK_Return: "Return picks the colour.", kVK_ANSI_KeypadEnter: "Return picks the colour.",
        kVK_Escape: "Esc cancels the picker.", kVK_LeftArrow: "The arrow keys always work.",
        kVK_RightArrow: "The arrow keys always work.", kVK_UpArrow: "The arrow keys always work.",
        kVK_DownArrow: "The arrow keys always work.",
    ]

    private var top: Int
    private var left: Int
    private var bottom: Int
    private var right: Int

    public var preset: Preset? {
        Preset.allCases.first { $0.letters == letters }
    }

    var hint: String {
        if let preset { return preset.hint }
        let extras = Direction.allCases.filter { self[$0] != $0.arrowKey }
        return "arrows or " + extras.map(label(of:)).joined()
    }

    var letters: [Int] {
        Direction.allCases.map { self[$0] }
    }

    public init() {
        top = kVK_UpArrow
        left = kVK_LeftArrow
        bottom = kVK_DownArrow
        right = kVK_RightArrow
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        top = try values.decodeIfPresent(Int.self, forKey: .top) ?? top
        left = try values.decodeIfPresent(Int.self, forKey: .left) ?? left
        bottom = try values.decodeIfPresent(Int.self, forKey: .bottom) ?? bottom
        right = try values.decodeIfPresent(Int.self, forKey: .right) ?? right
    }

    public func label(of direction: Direction) -> String {
        HotKeyLabel.keyName(UInt32(self[direction]))
    }

    public mutating func choose(_ preset: Preset) {
        for (direction, key) in zip(Direction.allCases, preset.letters) {
            self[direction] = key
        }
    }

    public mutating func assign(_ keyCode: Int, to direction: Direction) -> String? {
        if keyCode != direction.arrowKey, let refusal = Self.refusals[keyCode] {
            return refusal
        }
        if let other = Direction.allCases.first(where: { $0 != direction && self[$0] == keyCode }) {
            return "\(HotKeyLabel.keyName(UInt32(keyCode))) already moves "
                + "\(other.title.lowercased())."
        }
        self[direction] = keyCode
        return nil
    }

    func input(for keyCode: Int) -> ColourLoupe.Input? {
        switch keyCode {
        case kVK_Return, kVK_ANSI_KeypadEnter: return .picked
        case kVK_Escape: return .cancelled
        default: break
        }
        return Direction.allCases.first { direction in
            direction.arrowKey == keyCode || self[direction] == keyCode
        }?.input
    }

    public subscript(direction: Direction) -> Int {
        get {
            switch direction {
            case .top: top
            case .left: left
            case .bottom: bottom
            case .right: right
            }
        }
        set {
            switch direction {
            case .top: top = newValue
            case .left: left = newValue
            case .bottom: bottom = newValue
            case .right: right = newValue
            }
        }
    }
}
