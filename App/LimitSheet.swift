import AppKit
import ClipboardKit

@MainActor
final class LimitSheet: NSObject, NSTextFieldDelegate {
    struct Unit {
        let title: String
        let range: ClosedRange<Int>
    }

    private static let fieldWidth: CGFloat = 96
    private static let width: CGFloat = 240
    private static let hintSize: CGFloat = 11

    private let alert = NSAlert()
    private let field = NSTextField()
    private let unitMenu = NSPopUpButton()
    private let hint = NSTextField(labelWithString: "")
    private let units: [Unit]

    private var count: Int? {
        ClipboardStore.Retention.count(in: field.stringValue, within: unit.range)
    }

    private var unit: Unit {
        units[max(unitMenu.indexOfSelectedItem, 0)]
    }

    init(_ title: String, count: Int?, units: [Unit], selected: Int) {
        self.units = units
        super.init()
        alert.messageText = title
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        field.stringValue = count?.formatted() ?? ""
        field.delegate = self
        field.setAccessibilityLabel(title)
        field.widthAnchor.constraint(equalToConstant: Self.fieldWidth).isActive = true
        unitMenu.addItems(withTitles: units.map(\.title))
        unitMenu.selectItem(at: selected)
        unitMenu.target = self
        unitMenu.action = #selector(unitChanged)
        unitMenu.setAccessibilityLabel("Unit")
        let unitView: NSView =
            units.count > 1 ? unitMenu : NSTextField(labelWithString: units.first?.title ?? "")
        hint.font = .systemFont(ofSize: Self.hintSize)
        hint.textColor = .secondaryLabelColor
        update()
        let entry = NSStackView(views: [field, unitView])
        let content = NSStackView(views: [entry, hint])
        content.orientation = .vertical
        content.alignment = .leading
        content.layoutSubtreeIfNeeded()
        content.frame.size = NSSize(width: Self.width, height: content.fittingSize.height)
        alert.accessoryView = content
    }

    func begin(on window: NSWindow, save: @escaping (_ count: Int, _ unit: Int) -> Void) {
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { [self] response in
            guard response == .alertFirstButtonReturn, let count else { return }
            save(count, unitMenu.indexOfSelectedItem)
        }
    }

    func controlTextDidChange(_: Notification) {
        update()
    }

    @objc
    private func unitChanged() {
        update()
    }

    private func update() {
        let range = unit.range
        hint.stringValue =
            "Use a whole number from \(range.lowerBound.formatted())"
            + " to \(range.upperBound.formatted())."
        alert.buttons.first?.isEnabled = count != nil
    }
}
