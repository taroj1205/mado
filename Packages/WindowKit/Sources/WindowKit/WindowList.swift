public import ApplicationServices

@AccessibilityActor
public final class WindowList {
    public typealias Failure = FocusedWindow.Failure

    public struct Window: Equatable, Sendable {
        public let id: Int
        public let pid: pid_t
        public let title: String
        public internal(set) var number: CGWindowID?
    }

    struct Placement: Equatable {
        let pid: pid_t
        let frame: CGRect?
    }

    public static let shared = WindowList()

    private var listed: [Int: FocusedWindow] = [:]
    private var nextID = 0

    nonisolated static func frontToBack(_ windows: [Placement], onScreen: [Placement]) -> [Int] {
        let ranks = windows.map { onScreen.firstIndex(of: $0) ?? onScreen.count }
        return windows.indices.sorted { (ranks[$0], $0) < (ranks[$1], $1) }
    }

    nonisolated private static func onScreen() -> [(placement: Placement, number: CGWindowID)] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        return (info ?? []).compactMap { entry in
            guard entry[kCGWindowLayer as String] as? Int == 0,
                let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                let number = entry[kCGWindowNumber as String] as? CGWindowID
            else { return nil }
            return (Placement(pid: pid, frame: frame), number)
        }
    }

    private static func standardWindows(of application: AXUIElement) -> [AXUIElement] {
        let list =
            (try? FocusedWindow.copy(kAXWindowsAttribute, of: application)) as? [AXUIElement]
        return (list ?? []).filter { window in
            (try? FocusedWindow.copy(kAXSubroleAttribute, of: window)) as? String
                == kAXStandardWindowSubrole
        }
    }

    private static func set(_ name: String, _ value: Bool, on node: AXUIElement) throws(Failure) {
        let error = AXUIElementSetAttributeValue(
            node, name as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
        guard error == .success || FocusedWindow.refusal(error) else {
            throw FocusedWindow.failure(error)
        }
    }

    private static func perform(_ action: String, on element: AXUIElement) throws(Failure) {
        let error = AXUIElementPerformAction(element, action as CFString)
        guard error == .success || FocusedWindow.refusal(error) else {
            throw FocusedWindow.failure(error)
        }
    }

    public func load(from pids: [pid_t]) -> [Window] {
        listed = [:]
        var found: [(window: Window, placement: Placement)] = []
        for pid in pids {
            let application = AXUIElementCreateApplication(pid)
            AXUIElementSetMessagingTimeout(application, FocusedWindow.messagingTimeout)
            for element in Self.standardWindows(of: application) {
                let window = FocusedWindow(application: application, element: element)
                let title = (try? FocusedWindow.copy(kAXTitleAttribute, of: element)) as? String
                let id = nextID
                nextID += 1
                listed[id] = window
                let placement = Placement(pid: pid, frame: try? window.quartzFrame())
                found.append((Window(id: id, pid: pid, title: title ?? ""), placement))
            }
        }
        let onScreen = Self.onScreen()
        let order = Self.frontToBack(found.map(\.placement), onScreen: onScreen.map(\.placement))
        return order.map { index in
            var window = found[index].window
            window.number = onScreen.first { $0.placement == found[index].placement }?.number
            return window
        }
    }

    public func focus(_ id: Int) throws(Failure) {
        guard let window = listed[id] else { throw .noWindow }
        try Self.set(kAXHiddenAttribute, false, on: window.application)
        try Self.set(kAXMinimizedAttribute, false, on: window.element)
        try Self.perform(kAXRaiseAction, on: window.element)
        try Self.set(kAXMainAttribute, true, on: window.element)
        try Self.set(kAXFrontmostAttribute, true, on: window.application)
    }

    public func close(_ id: Int) throws(Failure) {
        guard let window = listed[id] else { throw .noWindow }
        let button = try FocusedWindow.copy(kAXCloseButtonAttribute, of: window.element)
        guard CFGetTypeID(button) == AXUIElementGetTypeID() else { throw .noWindow }
        try Self.perform(kAXPressAction, on: unsafe unsafeDowncast(button, to: AXUIElement.self))
        listed[id] = nil
    }
}
