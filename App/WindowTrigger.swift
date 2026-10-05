import AppCore
import AppKit
import GlassUI
import os
import WindowKit

@MainActor
enum WindowTrigger: CaseIterable {
    case move
    case radial
    case resize

    private static let footerSize: CGFloat = 12
    static let footer = NSAttributedString(
        string: "The radial menu, move and resize each need their own keys. "
            + "A combination already in use is refused.",
        attributes: [
            .font: NSFont.systemFont(ofSize: footerSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])

    private static func write<Value: StoredValue>(
        _ held: Shortcut.Modifiers, to path: WritableKeyPath<Value, Shortcut.Modifiers>,
        in modules: ModuleManager
    ) throws {
        var value = Value.load(from: modules)
        value[keyPath: path] = held
        try modules.setValue(value, for: Value.key)
    }

    func button(_ modules: ModuleManager?) -> TriggerButton {
        let button = TriggerButton()
        button.modifiers = held(in: modules)
        button.onChange = { [weak button] held in
            save(held, to: modules)
            button?.modifiers = self.held(in: modules)
        }
        return button
    }

    private func held(in modules: ModuleManager?) -> Shortcut.Modifiers {
        switch self {
        case .move: GestureSettings.load(from: modules).move
        case .radial: RadialSettings.load(from: modules).trigger
        case .resize: GestureSettings.load(from: modules).resize
        }
    }

    private func save(_ held: Shortcut.Modifiers, to modules: ModuleManager?) {
        guard let modules, held != self.held(in: modules) else { return }
        guard !Self.allCases.contains(where: { $0 != self && $0.held(in: modules) == held }) else {
            NSSound.beep()
            return
        }
        do {
            switch self {
            case .move: try Self.write(held, to: \GestureSettings.move, in: modules)
            case .radial: try Self.write(held, to: \RadialSettings.trigger, in: modules)
            case .resize: try Self.write(held, to: \GestureSettings.resize, in: modules)
            }
            try modules.restart(WindowsModule.id)
        } catch {
            Log.logger("Settings").error(
                "Window trigger failed to save: \(error, privacy: .public)")
            NSApp.presentError(error)
        }
    }
}
