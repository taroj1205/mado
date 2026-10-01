import AppKit

// swiftlint:disable no_magic_numbers
@MainActor
enum HotkeyRecorderStyle {
    static let cardWidth: CGFloat = 330
    static let cardRadius: CGFloat = 20
    static let cardBorderWidth: CGFloat = 1
    static let inset: CGFloat = 16
    static let spacing: CGFloat = 10
    static let keySpacing: CGFloat = 5
    static let buttonSpacing: CGFloat = 6
    static let warningSpacing: CGFloat = 8
    static let warningIconWidth: CGFloat = 14

    static let fieldHeight: CGFloat = 52
    static let fieldRadius: CGFloat = 12
    static let fieldBorderWidth: CGFloat = 1.5
    static let fieldBorderInset: CGFloat = 0.75
    static let dashLength: CGFloat = 4
    static let dashGap: CGFloat = 3
    static let dashPattern = [dashLength, dashGap]
    static let dashPhase: CGFloat = 0

    static let keyCapHeight: CGFloat = 30
    static let keyCapRadius: CGFloat = 5
    static let keyCapPadding: CGFloat = 5

    static let pillHeight: CGFloat = 26
    static let pillRadius: CGFloat = 13
    static let pillHorizontalPadding: CGFloat = 24

    static let dotSize: CGFloat = 8
    static let dotRadius: CGFloat = 4
    static let warningTextWidth = cardWidth - 2 * inset - warningIconWidth - warningSpacing

    static let noteSize: CGFloat = 12
    static let bodySize: CGFloat = 13
    static let keyCapSize: CGFloat = 15
    static let noteFont = NSFont.systemFont(ofSize: noteSize)
    static let bodyFont = NSFont.systemFont(ofSize: bodySize)
    static let pillFont = NSFont.systemFont(ofSize: bodySize, weight: .medium)
    static let keyCapFont = NSFont.systemFont(ofSize: keyCapSize, weight: .medium)

    static let cardBorder = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    static let fieldFill = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.25)
    static let keyCapFill = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.16)
    static let keyCapText = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92)
    static let pillFill = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.10)
    static let secondary = NSColor(srgbRed: 0.92, green: 0.92, blue: 0.96, alpha: 0.6)
    static let waitingBorder = NSColor(srgbRed: 0.92, green: 0.92, blue: 0.96, alpha: 0.18)
    static let blue = NSColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)
    static let orange = NSColor(srgbRed: 1, green: 0.62, blue: 0.04, alpha: 1)
    static let red = NSColor(srgbRed: 1, green: 0.27, blue: 0.23, alpha: 1)
    static let warningText = NSColor(srgbRed: 1, green: 0.7, blue: 0.25, alpha: 1)
}
// swiftlint:enable no_magic_numbers
