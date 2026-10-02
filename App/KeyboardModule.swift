import AppCore
import AppKit
import ApplicationServices
import GlassUI
import InputKit
import os

final class KeyboardModule: Module {
    static let id = "keyboard"
    private static let retryInterval: Duration = .seconds(1)
    nonisolated private static let caretTimeout: Float = 0.25
    private static let pointerHeight: CGFloat = 24

    let descriptor: ModuleDescriptor
    private let hud = InputModeHUD()
    private var pending: Task<Void, Never>?

    init(descriptor: ModuleDescriptor) {
        self.descriptor = descriptor
    }

    private static func screenRect(_ caret: CGRect?) -> CGRect {
        guard let caret, let primary = NSScreen.screens.first else {
            let pointer = NSEvent.mouseLocation
            return CGRect(
                x: pointer.x, y: pointer.y - pointerHeight, width: 0, height: pointerHeight)
        }
        return CGRect(
            x: caret.minX, y: primary.frame.maxY - caret.maxY, width: caret.width,
            height: caret.height)
    }

    nonisolated private static func caret(in pid: pid_t) -> CGRect? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, caretTimeout)
        guard
            let focused: AXUIElement = copy(
                kAXFocusedUIElementAttribute, of: app, typeID: AXUIElementGetTypeID())
        else {
            return nil
        }
        AXUIElementSetMessagingTimeout(focused, caretTimeout)
        guard
            let range: AXValue = copy(
                kAXSelectedTextRangeAttribute, of: focused, typeID: AXValueGetTypeID()),
            let bounds: AXValue = copy(
                kAXBoundsForRangeParameterizedAttribute, of: focused, typeID: AXValueGetTypeID(),
                parameter: range)
        else {
            return nil
        }
        var rect = CGRect.zero
        guard unsafe AXValueGetValue(bounds, .cgRect, &rect), rect.height > 0 else { return nil }
        return rect
    }

    nonisolated private static func copy<Value: AnyObject>(
        _ attribute: String, of element: AXUIElement, typeID: CFTypeID,
        parameter: CFTypeRef? = nil
    ) -> Value? {
        var value: CFTypeRef?
        let error =
            if let parameter {
                unsafe AXUIElementCopyParameterizedAttributeValue(
                    element, attribute as CFString, parameter, &value)
            } else {
                unsafe AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
            }
        guard error == .success, let value, CFGetTypeID(value) == typeID else { return nil }
        return unsafe unsafeDowncast(value, to: Value.self)
    }

    func start(context: ModuleContext) {
        guard !installTap(context) else { return }
        context.logger.notice("Input mode taps wait for Accessibility")
        context.run("wait for Accessibility") { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.retryInterval)
                guard let self, !Task.isCancelled else { return }
                if installTap(context) { return }
            }
        }
    }

    func stop() {
        pending?.cancel()
        hud.close()
    }

    private func installTap(_ context: ModuleContext) -> Bool {
        do {
            try ModifierTap.install(name: "input mode taps", context: context) { [weak self] key in
                self?.tapped(key)
            }
            return true
        } catch {
            return false
        }
    }

    private func tapped(_ key: ModifierTap.Key) {
        let mode: InputMode
        let side: String
        switch key {
        case .leftCommand: (mode, side) = (.english, "left ⌘")
        case .rightCommand: (mode, side) = (.japanese, "right ⌘")
        default: return
        }
        guard mode.select() else { return }
        let (glyph, title) =
            switch mode {
            case .english: ("A", "英数")
            case .japanese: ("あ", "かな")
            }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier
        pending?.cancel()
        pending = Task { [weak self] in
            let caret = await Task.detached { pid.flatMap(Self.caret(in:)) }.value
            guard let self, !Task.isCancelled else { return }
            hud.show(glyph: glyph, title: title, detail: side, below: Self.screenRect(caret))
        }
    }
}
