import AppKit
public import ApplicationServices

public struct FocusedWindow {
    public enum Failure: Error, Equatable {
        case notAllowed
        case noWindow
        case failed(AXError)
    }

    let element: AXUIElement

    public init(pid: pid_t) throws(Failure) {
        let window = try Self.copy(kAXFocusedWindowAttribute, of: AXUIElementCreateApplication(pid))
        guard CFGetTypeID(window) == AXUIElementGetTypeID() else { throw .noWindow }
        element = unsafe unsafeDowncast(window, to: AXUIElement.self)
    }

    public static func frontmost() throws(Failure) -> Self {
        guard let app = NSWorkspace.shared.frontmostApplication else { throw .noWindow }
        return try Self(pid: app.processIdentifier)
    }

    static func failure(_ error: AXError) -> Failure {
        switch error {
        case .apiDisabled: .notAllowed
        case .noValue, .attributeUnsupported: .noWindow
        default: .failed(error)
        }
    }

    static func frame(position: CFTypeRef, size: CFTypeRef) -> CGRect? {
        let axValue = AXValueGetTypeID()
        guard CFGetTypeID(position) == axValue, CFGetTypeID(size) == axValue else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard unsafe AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &origin),
            unsafe AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent)
        else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    private static func copy(_ name: String, of element: AXUIElement) throws(Failure) -> CFTypeRef {
        var value: CFTypeRef?
        let error = unsafe AXUIElementCopyAttributeValue(element, name as CFString, &value)
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
}
