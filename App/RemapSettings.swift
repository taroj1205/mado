import AppCore
import AppKit
import GlassUI
import InputKit

struct RemapSettings: StoredValue, Equatable {
    static let key = "remaps"

    var capsLock: CapsLockRemap
    var tapsEscape: Bool

    init() {
        capsLock = .capsLock
        tapsEscape = false
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        capsLock = try values.decodeIfPresent(CapsLockRemap.self, forKey: .capsLock) ?? capsLock
        tapsEscape = try values.decodeIfPresent(Bool.self, forKey: .tapsEscape) ?? tapsEscape
    }

    @MainActor
    static func sections(_ modules: ModuleManager?) -> [SettingsSection] {
        let remaps = CapsLockRemap.allCases
        let tap = SettingsSwitch(
            read: { load(from: modules).tapsEscape },
            write: { isOn in try update(modules) { $0.tapsEscape = isOn } })
        let canTap = { modules != nil && load(from: modules).capsLock == .hyper }
        tap.isEnabled = canTap()
        let becomes = SettingsSegments(
            remaps.map(\.title),
            read: { remaps.firstIndex(of: load(from: modules).capsLock) ?? 0 },
            write: { index in
                try update(modules) { $0.capsLock = remaps[index] }
                tap.isEnabled = canTap()
            })
        becomes.isEnabled = modules != nil
        return [
            SettingsSection(
                "Caps Lock",
                [
                    .init("Caps Lock key becomes", becomes),
                    .init("Tap alone sends Escape", tap, example: nil) {
                        "Hold for Hyper, tap for Escape."
                    },
                    .init(
                        "Hyper is", ModifierKeycaps([.control, .option, .shift, .command]),
                        example: nil
                    ) {
                        "Record Hyper+T, Hyper+N… anywhere a hotkey is recorded —\n"
                            + "they never clash with app shortcuts."
                    },
                ])
        ]
    }

    @MainActor
    private static func update(_ modules: ModuleManager?, _ change: (inout Self) -> Void) throws {
        var settings = load(from: modules)
        change(&settings)
        try modules?.setValue(settings, for: key)
        try modules?.restart(KeyboardModule.id)
    }
}

extension CapsLockRemap {
    var title: String {
        switch self {
        case .capsLock: "Caps Lock"
        case .control: "Control"
        case .escape: "Escape"
        case .hyper: "Hyper"
        }
    }
}
