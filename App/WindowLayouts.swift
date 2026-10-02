import AppCore
import AppKit
import Carbon.HIToolbox
import GlassUI
import WindowKit

@MainActor
enum WindowLayouts {
    struct Entry {
        private static let screen = CGRect(x: 0, y: 0, width: 1, height: 1)
        private static let centreWidth: CGFloat = 0.56
        private static let centreHeight: CGFloat = 0.64

        let id: String
        let title: String
        let symbol: String
        let placement: WindowPlacement
        let hotkey: Shortcut
        let keywords: [String]

        var glyph: CGRect {
            switch placement {
            case .layout(let action):
                let frame = LayoutEngine.frame(
                    for: action, in: Self.screen, gap: 0,
                    windowSize: CGSize(width: Self.centreWidth, height: Self.centreHeight))
                return CGRect(
                    x: frame.minX, y: Self.screen.maxY - frame.maxY, width: frame.width,
                    height: frame.height)

            case .display:
                return Self.screen

            case .restore:
                return .zero
            }
        }

        init(
            _ id: String, _ title: String, _ symbol: String, _ placement: WindowPlacement,
            _ hotkey: Shortcut
        ) {
            self.init(id, title, symbol, placement, hotkey, keywords: [])
        }

        init(
            _ id: String, _ title: String, _ symbol: String, _ placement: WindowPlacement,
            _ hotkey: Shortcut, keywords: [String]
        ) {
            self.id = "window.\(id)"
            self.title = title
            self.symbol = symbol
            self.placement = placement
            self.hotkey = hotkey
            self.keywords = ["window", "layout"] + keywords
        }
    }

    private static let columns = 2
    private static let twoThirds = "rectangle.split.3x1"
    private static let display = "rectangle.portrait.and.arrow.right"

    static let all: [Entry] = [
        Entry(
            "left-half", "Left Half", "rectangle.lefthalf.inset.filled", .layout(.leftHalf),
            key(kVK_LeftArrow)),
        Entry(
            "right-half", "Right Half", "rectangle.righthalf.inset.filled", .layout(.rightHalf),
            key(kVK_RightArrow)),
        Entry(
            "top-half", "Top Half", "rectangle.tophalf.inset.filled", .layout(.topHalf),
            key(kVK_UpArrow)),
        Entry(
            "bottom-half", "Bottom Half", "rectangle.bottomhalf.inset.filled",
            .layout(.bottomHalf), key(kVK_DownArrow)),
        Entry(
            "top-left-quarter", "Top Left", "rectangle.inset.topleft.filled",
            .layout(.topLeftQuarter), key(kVK_ANSI_U), keywords: ["quarter"]),
        Entry(
            "top-right-quarter", "Top Right", "rectangle.inset.topright.filled",
            .layout(.topRightQuarter), key(kVK_ANSI_I), keywords: ["quarter"]),
        Entry(
            "bottom-left-quarter", "Bottom Left", "rectangle.inset.bottomleft.filled",
            .layout(.bottomLeftQuarter), key(kVK_ANSI_J), keywords: ["quarter"]),
        Entry(
            "bottom-right-quarter", "Bottom Right", "rectangle.inset.bottomright.filled",
            .layout(.bottomRightQuarter), key(kVK_ANSI_K), keywords: ["quarter"]),
        Entry(
            "first-third", "First Third", "rectangle.leadingthird.inset.filled",
            .layout(.leftThird), key(kVK_ANSI_D)),
        Entry(
            "center-third", "Center Third", "rectangle.center.inset.filled",
            .layout(.centreThird), key(kVK_ANSI_F), keywords: ["centre third"]),
        Entry(
            "last-third", "Last Third", "rectangle.trailingthird.inset.filled",
            .layout(.rightThird), key(kVK_ANSI_G)),
        Entry(
            "first-two-thirds", "First Two Thirds", twoThirds, .layout(.leftTwoThirds),
            key(kVK_ANSI_E)),
        Entry(
            "last-two-thirds", "Last Two Thirds", twoThirds, .layout(.rightTwoThirds),
            key(kVK_ANSI_T)),
        Entry(
            "maximise", "Maximise", "rectangle.inset.filled", .layout(.maximize),
            key(kVK_Return), keywords: ["maximize"]),
        Entry(
            "almost-maximise", "Almost Maximise", "rectangle.inset.filled",
            .layout(.almostMaximize), key(kVK_Return, [.control, .option, .shift]),
            keywords: ["almost maximize"]),
        Entry(
            "center", "Center", "rectangle.center.inset.filled", .layout(.centre),
            key(kVK_ANSI_C), keywords: ["centre"]),
        Entry("restore", "Restore", "arrow.uturn.backward", .restore, key(kVK_Delete)),
        Entry(
            "next-display", "Next Display", display, .display(step: 1),
            key(kVK_RightArrow, [.control, .option, .command])),
        Entry(
            "previous-display", "Previous Display", display, .display(step: -1),
            key(kVK_LeftArrow, [.control, .option, .command])),
    ]

    private static func key(
        _ code: Int, _ modifiers: Shortcut.Modifiers = [.control, .option]
    ) -> Shortcut {
        Shortcut(keyCode: UInt32(code), modifiers: modifiers)
    }

    static func commands(gap: @escaping @MainActor () -> CGFloat) -> [Command] {
        all.map { entry in
            Command(
                id: entry.id, name: entry.title, icon: entry.symbol,
                actions: [
                    CommandAction(id: "place", title: entry.title) {
                        let screens = NSScreen.screens.map { screen in
                            ScreenGeometry.Screen(
                                frame: screen.frame, visibleFrame: screen.visibleFrame)
                        }
                        try await entry.placement.apply(gap: gap(), across: screens)
                    }
                ],
                keywords: entry.keywords)
        }
    }

    static func assignDefaultHotKeys(in editor: ItemEditor, modules: ModuleManager?) {
        var settings = LayoutSettings.load(from: modules)
        guard !settings.assignedDefaultHotKeys, modules?.isEnabled(WindowsModule.id) == true
        else { return }
        editor.assignDefaults(all.map { ($0.id, $0.hotkey) })
        settings.assignedDefaultHotKeys = true
        settings.save(to: modules)
    }

    static func sections(recorder: HotKeyPopover, modules: ModuleManager?) -> [SettingsSection] {
        let rows = all.map { entry in
            SettingsSection.Row(
                entry.title, recorder.button(for: entry.id, named: entry.title),
                icon: LayoutGlyphView(area: entry.glyph))
        }
        return [
            SettingsSection("Layouts", columns: columns, rows),
            SettingsSection("Behaviour", [.init("Gap between windows", gapPopUp(modules))]),
        ]
    }

    private static func gapPopUp(_ modules: ModuleManager?) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = LayoutSettings.load(from: modules).gap
            let choices = LayoutSettings.gaps.map { gap in
                SettingsPopUp.Choice(title: "\(Int(gap)) pt", isSelected: gap == current) {
                    var settings = LayoutSettings.load(from: modules)
                    settings.gap = gap
                    settings.save(to: modules)
                }
            }
            return [SettingsPopUp.Section(title: nil, choices: choices)]
        }
        popUp.isEnabled = modules != nil
        return popUp
    }
}
