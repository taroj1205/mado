public import ApplicationServices

@AccessibilityActor
public final class WindowList {
    public typealias Failure = FocusedWindow.Failure
    typealias Match = (window: Int, stack: Int?)

    public struct Window: Equatable, Sendable {
        public let id: Int
        public let pid: pid_t
        public let title: String
        public internal(set) var number: CGWindowID?
    }

    struct Placement {
        let pid: pid_t
        let frame: CGRect?
        let title: String

        func fits(_ other: Self, byTitle: Bool) -> Bool {
            pid == other.pid && frame == other.frame && (!byTitle || title == other.title)
        }
    }

    public static let shared = WindowList()

    private var listed: [Int: FocusedWindow] = [:]
    private var nextID = 0

    nonisolated static func frontToBack(_ windows: [Placement], in stack: [Placement]) -> [Match] {
        var matches = [Int?](repeating: nil, count: windows.count)
        var taken = Set<Int>()
        for byTitle in [true, false] {
            for (index, window) in windows.enumerated() where matches[index] == nil {
                matches[index] = stack.indices.first { candidate in
                    !taken.contains(candidate) && window.fits(stack[candidate], byTitle: byTitle)
                }
                if let match = matches[index] { taken.insert(match) }
            }
        }
        let rank = { (index: Int) in (matches[index] ?? stack.count, index) }
        return windows.indices.sorted { rank($0) < rank($1) }.map { ($0, matches[$0]) }
    }

    nonisolated public static func groupedByApp(_ windows: [Window]) -> [Window] {
        var apps: [pid_t] = []
        for window in windows where !apps.contains(window.pid) {
            apps.append(window.pid)
        }
        return apps.flatMap { pid in windows.filter { $0.pid == pid } }
    }

    nonisolated private static func stack() -> [(placement: Placement, number: CGWindowID)] {
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        let windows = (info ?? []).filter { $0[kCGWindowLayer as String] as? Int == 0 }
        let visible = windows.filter { $0[kCGWindowIsOnscreen as String] as? Bool == true }
        let hidden = windows.filter { $0[kCGWindowIsOnscreen as String] as? Bool != true }
        return (visible + hidden).compactMap { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
                let bounds = entry[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
                let number = entry[kCGWindowNumber as String] as? CGWindowID
            else { return nil }
            let title = entry[kCGWindowName as String] as? String ?? ""
            return (Placement(pid: pid, frame: frame, title: title), number)
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
                let placement = Placement(
                    pid: pid, frame: try? window.quartzFrame(), title: title ?? "")
                found.append((Window(id: id, pid: pid, title: placement.title), placement))
            }
        }
        let stack = Self.stack()
        let order = Self.frontToBack(found.map(\.placement), in: stack.map(\.placement))
        return order.map { index, match in
            var window = found[index].window
            window.number = match.map { stack[$0].number }
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
