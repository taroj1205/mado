import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct RadialEditorTests {
    private static let maximize = RadialEditor.Choice(
        id: "maximize", title: "Maximize", detail: nil,
        glyph: CGRect(x: 0, y: 0, width: 1, height: 1), cycles: false)
    private static let leftCycle = RadialEditor.Choice(
        id: "left_cycle", title: "Left cycle", detail: "½ → ⅓ → ⅔",
        glyph: CGRect(x: 0, y: 0, width: 0.5, height: 1), cycles: true)
    private static let nothing = RadialEditor.Choice(
        id: "nothing", title: "Nothing", detail: "ignored", glyph: .zero,
        cycles: false)

    private let editor = RadialEditor(groups: [
        RadialEditor.Group(title: "Fill", choices: [maximize]),
        RadialEditor.Group(title: "Cycles", choices: [leftCycle]),
        RadialEditor.Group(title: "Other", choices: [nothing]),
    ])

    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 640, height: 360), styleMask: [.titled],
        backing: .buffered, defer: true)

    init() {
        window.contentView = editor
        var actions = Dictionary(
            uniqueKeysWithValues: RadialEditor.Slot.allCases.map { ($0, Self.nothing.id) })
        actions[.ring] = Self.maximize.id
        actions[.left] = Self.leftCycle.id
        editor.actions = actions
    }

    private func button(_ slot: RadialEditor.Slot) throws -> RadialSlotButton {
        try #require(editor.slots[slot])
    }

    private func row(_ choice: RadialEditor.Choice) throws -> RadialChoiceRow {
        try #require(editor.inspector.rows.first { $0.choice == choice })
    }

    @Test func everySlotIsAButtonNamedWithItsAction() throws {
        #expect(editor.slots.count == RadialEditor.Slot.allCases.count)
        #expect(try button(.ring).accessibilityLabel() == "Ring: Maximize")
        #expect(try button(.left).accessibilityLabel() == "Left: Left cycle")
        #expect(try button(.topRight).accessibilityLabel() == "Top right: Nothing")
        #expect(editor.hole.accessibilityLabel() == "Centre hole: cancel. Fixed")
        for button in Array(editor.slots.values) + [editor.hole] {
            #expect(button.isAccessibilityElement())
            #expect(button.accessibilityRole() == .radioButton)
        }
    }

    @Test func theRingStartsSelectedWithItsActionTicked() throws {
        #expect(editor.selection == .slot(.ring))
        #expect(try button(.ring).isChosen)
        #expect(try button(.ring).accessibilityValue() as? Int == 1)
        #expect(try button(.left).accessibilityValue() as? Int == 0)
        #expect(try row(Self.maximize).isChosen)
        #expect(try row(Self.maximize).accessibilityValue() as? Int == 1)
        #expect(try row(Self.leftCycle).accessibilityValue() as? Int == 0)
        #expect(try !row(Self.leftCycle).isChosen)
        #expect(editor.inspector.heading.stringValue == "Ring")
    }

    @Test(arguments: RadialEditor.Slot.allCases)
    func pressingASlotThenAnActionChangesThatSlot(slot: RadialEditor.Slot) throws {
        var picked: [(RadialEditor.Slot, String)] = []
        editor.onPick = { picked.append(($0, $1)) }

        #expect(try button(slot).accessibilityPerformPress())
        #expect(editor.selection == .slot(slot))
        #expect(try button(slot).isChosen)
        #expect(editor.slots.filter(\.value.isChosen).count == 1)
        #expect(try row(Self.leftCycle).accessibilityPerformPress())

        #expect(picked.map(\.0) == [slot])
        #expect(picked.map(\.1) == [Self.leftCycle.id])
        #expect(editor.actions[slot] == Self.leftCycle.id)
        #expect(try button(slot).accessibilityLabel() == "\(slot.name): Left cycle")
        #expect(try button(slot).cycles)
        #expect(try row(Self.leftCycle).isChosen)
        #expect(try !row(Self.nothing).isChosen)
    }

    @Test func theHoleExplainsItselfAndCannotBeChanged() throws {
        var picked = 0
        editor.onPick = { _, _ in picked += 1 }

        #expect(editor.hole.accessibilityPerformPress())

        #expect(editor.selection == .hole)
        #expect(editor.hole.isChosen)
        #expect(editor.slots.values.allSatisfy { !$0.isChosen })
        #expect(editor.inspector.heading.stringValue == "Hole · Cancel")
        #expect(editor.inspector.rows.allSatisfy { !$0.isChosen })
        _ = try row(Self.leftCycle).accessibilityPerformPress()
        #expect(picked == 0)
    }
}
