import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct WindowListTests {
    typealias Placement = WindowList.Placement

    static let left = CGRect(x: 0, y: 25, width: 600, height: 400)
    static let right = CGRect(x: 600, y: 25, width: 600, height: 400)

    @Test func sortsWindowsByTheirOnScreenStackingOrder() {
        let windows = [
            Placement(pid: 1, frame: Self.left), Placement(pid: 2, frame: Self.left),
            Placement(pid: 1, frame: Self.right),
        ]
        let onScreen = [
            Placement(pid: 1, frame: Self.right), Placement(pid: 2, frame: Self.left),
            Placement(pid: 1, frame: Self.left),
        ]
        #expect(WindowList.frontToBack(windows, onScreen: onScreen) == [2, 1, 0])
    }

    @Test func keepsOffScreenWindowsLastInTheirListedOrder() {
        let windows = [
            Placement(pid: 3, frame: nil), Placement(pid: 1, frame: Self.left),
            Placement(pid: 2, frame: Self.right), Placement(pid: 1, frame: Self.right),
        ]
        let onScreen = [Placement(pid: 1, frame: Self.left)]
        #expect(WindowList.frontToBack(windows, onScreen: onScreen) == [1, 0, 2, 3])
    }

    @Test func matchesAWindowOnlyToItsOwnApp() {
        let windows = [Placement(pid: 1, frame: Self.left), Placement(pid: 2, frame: Self.left)]
        let onScreen = [Placement(pid: 2, frame: Self.left)]
        #expect(WindowList.frontToBack(windows, onScreen: onScreen) == [1, 0])
    }
}
