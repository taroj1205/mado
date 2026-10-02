import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowListTests {
    typealias Placement = WindowList.Placement

    static let left = CGRect(x: 0, y: 25, width: 600, height: 400)
    static let right = CGRect(x: 600, y: 25, width: 600, height: 400)

    private static func place(_ pid: pid_t, _ frame: CGRect?, _ title: String = "") -> Placement {
        Placement(pid: pid, frame: frame, title: title)
    }

    private static func arrange(_ windows: [Placement], _ stack: [Placement]) -> [[Int?]] {
        WindowList.frontToBack(windows, in: stack).map { [$0.window, $0.stack] }
    }

    @Test func sortsWindowsByTheirStackingOrder() {
        let windows = [
            Self.place(1, Self.left), Self.place(2, Self.left), Self.place(1, Self.right),
        ]
        let stack = [
            Self.place(1, Self.right), Self.place(2, Self.left), Self.place(1, Self.left),
        ]
        #expect(Self.arrange(windows, stack) == [[2, 0], [1, 1], [0, 2]])
    }

    @Test func keepsUnmatchedWindowsLastInTheirListedOrder() {
        let windows = [
            Self.place(3, nil), Self.place(1, Self.left), Self.place(2, Self.right),
            Self.place(1, Self.right),
        ]
        let stack = [Self.place(1, Self.left)]
        #expect(Self.arrange(windows, stack) == [[1, 0], [0, nil], [2, nil], [3, nil]])
    }

    @Test func matchesAWindowOnlyToItsOwnApp() {
        let windows = [Self.place(1, Self.left), Self.place(2, Self.left)]
        let stack = [Self.place(2, Self.left)]
        #expect(Self.arrange(windows, stack) == [[1, 0], [0, nil]])
    }

    @Test func givesSameFrameWindowsOfOneAppTheirOwnStackWindowByTitle() {
        let windows = [
            Self.place(1, Self.left, "a"), Self.place(1, Self.left, "b"),
            Self.place(1, Self.left, "c"),
        ]
        let stack = [
            Self.place(1, Self.left, "b"), Self.place(1, Self.left, ""),
            Self.place(1, Self.left, "a"),
        ]
        #expect(Self.arrange(windows, stack) == [[1, 0], [2, 1], [0, 2]])
    }

    @Test func groupsWindowsByAppInTheOrderTheirAppsFirstAppear() {
        let apps: [(pid_t, String)] = [(1, "a"), (2, "b"), (1, "c"), (3, "d"), (2, "e")]
        let windows = apps.enumerated().map { WindowList.Window(id: $0, pid: $1.0, title: $1.1) }
        #expect(WindowList.groupedByApp(windows).map(\.title) == ["a", "c", "b", "e", "d"])
    }
}
