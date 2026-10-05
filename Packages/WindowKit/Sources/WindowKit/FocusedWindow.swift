import AppKit
public import ApplicationServices

@AccessibilityActor
public struct FocusedWindow {
    public enum Failure: Error, Equatable {
        case notAllowed
        case noWindow
        case failed(AXError)
    }

    static let messagingTimeout: Float = 0.25
    private static let fullScreenAttribute = "AXFullScreen"

    let application: AXUIElement
    let element: AXUIElement

    var isVisible: Bool {
        !flag(kAXMinimizedAttribute, of: element) && !flag(kAXHiddenAttribute, of: application)
    }

    public init(pid: pid_t) throws(Failure) {
        application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)
        element = try Self.element(Self.copy(kAXFocusedWindowAttribute, of: application))
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    }

    init(application: AXUIElement, element: AXUIElement) {
        self.application = application
        self.element = element
        AXUIElementSetMessagingTimeout(element, Self.messagingTimeout)
    }

    public static func frontmost() throws(Failure) -> Self {
        guard let app = NSWorkspace.shared.frontmostApplication else { throw .noWindow }
        return try Self(pid: app.processIdentifier)
    }

    public static func under(quartzPoint point: CGPoint) throws(Failure) -> Self {
        let systemWide = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(systemWide, messagingTimeout)
        var hit: AXUIElement?
        let error = unsafe AXUIElementCopyElementAtPosition(
            systemWide, Float(point.x), Float(point.y), &hit)
        guard error == .success else { throw failure(error) }
        guard let hit else { throw .noWindow }
        let role = (try? copy(kAXRoleAttribute, of: hit)) as? String
        let window = role == kAXWindowRole ? hit : try element(copy(kAXWindowAttribute, of: hit))
        guard (try? copy(kAXSubroleAttribute, of: window)) as? String == kAXStandardWindowSubrole
        else { throw .noWindow }
        var pid: pid_t = 0
        guard unsafe AXUIElementGetPid(window, &pid) == .success else { throw .noWindow }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, messagingTimeout)
        return Self(application: app, element: window)
    }

    nonisolated static func failure(_ error: AXError) -> Failure {
        switch error {
        case .apiDisabled: .notAllowed
        case .noValue, .attributeUnsupported, .invalidUIElement: .noWindow
        default: .failed(error)
        }
    }

    nonisolated static func refusal(_ error: AXError) -> Bool {
        error == .failure || error == .attributeUnsupported || error == .illegalArgument
    }

    nonisolated static func frame(position: CFTypeRef, size: CFTypeRef) -> CGRect? {
        let axValue = AXValueGetTypeID()
        guard CFGetTypeID(position) == axValue, CFGetTypeID(size) == axValue else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard unsafe AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &origin),
            unsafe AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent)
        else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    private static func values(_ frame: CGRect) throws(Failure) -> (AXValue, AXValue) {
        var origin = frame.origin
        var size = frame.size
        guard let position = unsafe AXValueCreate(.cgPoint, &origin),
            let extent = unsafe AXValueCreate(.cgSize, &size)
        else { throw .failed(.illegalArgument) }
        return (position, extent)
    }

    private static func element(_ value: CFTypeRef) throws(Failure) -> AXUIElement {
        guard CFGetTypeID(value) == AXUIElementGetTypeID() else { throw .noWindow }
        return unsafe unsafeDowncast(value, to: AXUIElement.self)
    }

    static func copy(_ name: String, of element: AXUIElement) throws(Failure) -> CFTypeRef {
        var value: CFTypeRef?
        let error = AccessibilityActor.call(on: element) {
            unsafe AXUIElementCopyAttributeValue(element, name as CFString, &value)
        }
        guard error == .success else { throw failure(error) }
        guard let value else { throw .noWindow }
        return value
    }

    public func quartzFrame() throws(Failure) -> CGRect {
        let position = try Self.copy(kAXPositionAttribute, of: element)
        let size = try Self.copy(kAXSizeAttribute, of: element)
        guard let frame = Self.frame(position: position, size: size) else { throw .noWindow }
        return frame
    }

    private func flag(_ name: String, of element: AXUIElement) -> Bool {
        (try? Self.copy(name, of: element)) as? Bool ?? false
    }

    public func setFrame(_ frame: CGRect) throws(Failure) -> CGRect {
        let (position, extent) = try Self.values(frame)
        try set(kAXSizeAttribute, extent)
        try set(kAXPositionAttribute, position)
        try set(kAXSizeAttribute, extent)
        return try quartzFrame()
    }

    public func setFrame(_ frame: CGRect, changedFrom previous: CGRect) throws(Failure) {
        let (position, extent) = try Self.values(frame)
        if frame.size != previous.size {
            try set(kAXSizeAttribute, extent)
        }
        if frame.origin != previous.origin {
            try set(kAXPositionAttribute, position)
        }
    }

    public func enterFullScreen() throws(Failure) {
        try set(Self.fullScreenAttribute, kCFBooleanTrue)
    }

    private func set(_ name: String, _ value: CFTypeRef) throws(Failure) {
        let error = AccessibilityActor.call(on: element) {
            AXUIElementSetAttributeValue(element, name as CFString, value)
        }
        guard error == .success || Self.refusal(error) else { throw Self.failure(error) }
    }
}
