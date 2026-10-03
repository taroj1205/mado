public import ApplicationServices

public struct FocusedText: Sendable {
    public let isSecure: Bool
    public let caret: CGRect?
    public let textBeforeCaret: String?
    public let selectsText: Bool

    @AccessibilityActor
    public static func current(readingBack length: Int) -> Self? {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, FocusedWindow.messagingTimeout)
        guard let value = try? FocusedWindow.copy(kAXFocusedUIElementAttribute, of: systemWide),
            CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        let element = unsafe unsafeDowncast(value, to: AXUIElement.self)
        AXUIElementSetMessagingTimeout(element, FocusedWindow.messagingTimeout)
        let subrole = (try? FocusedWindow.copy(kAXSubroleAttribute, of: element)) as? String
        let selection = (try? FocusedWindow.copy(kAXSelectedTextRangeAttribute, of: element))
            .flatMap(range)
        return Self(
            isSecure: subrole == kAXSecureTextFieldSubrole,
            caret: selection.flatMap { caret(at: $0.location, in: element) },
            textBeforeCaret: selection.flatMap { selection in
                guard length > 0 else { return nil }
                return text(in: readBack(length, from: selection.location), of: element)
            },
            selectsText: (selection?.length ?? 0) > 0)
    }

    static func readBack(_ length: Int, from location: Int) -> CFRange {
        CFRange(location: max(location - length, 0), length: min(length, max(location, 0)))
    }

    static func range(_ value: CFTypeRef) -> CFRange? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        let axValue = unsafe unsafeDowncast(value, to: AXValue.self)
        guard unsafe AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        return range
    }

    static func rect(_ value: CFTypeRef) -> CGRect? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        let axValue = unsafe unsafeDowncast(value, to: AXValue.self)
        guard unsafe AXValueGetValue(axValue, .cgRect, &rect), rect.height > 0 else { return nil }
        return rect
    }

    @AccessibilityActor
    private static func caret(at location: Int, in element: AXUIElement) -> CGRect? {
        let before = CFRange(location: max(location - 1, 0), length: 1)
        return bounds(of: CFRange(location: location, length: 0), in: element)
            ?? bounds(of: before, in: element).map { rect in
                CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
            }
    }

    @AccessibilityActor
    private static func text(in range: CFRange, of element: AXUIElement) -> String? {
        var range = range
        guard let parameter = unsafe AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        let error = unsafe AXUIElementCopyParameterizedAttributeValue(
            element, kAXStringForRangeParameterizedAttribute as CFString, parameter, &value)
        guard error == .success else { return nil }
        return value as? String
    }

    @AccessibilityActor
    private static func bounds(of range: CFRange, in element: AXUIElement) -> CGRect? {
        var range = range
        guard let parameter = unsafe AXValueCreate(.cfRange, &range) else { return nil }
        var value: CFTypeRef?
        let error = unsafe AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, parameter, &value)
        guard error == .success, let value else { return nil }
        return rect(value)
    }
}
