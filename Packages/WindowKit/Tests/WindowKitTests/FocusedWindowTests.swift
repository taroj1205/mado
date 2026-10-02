import ApplicationServices
import Testing

@testable import WindowKit

@Suite struct FocusedWindowTests {
    static func wrap(_ point: CGPoint) -> AXValue? {
        var point = point
        return unsafe AXValueCreate(.cgPoint, &point)
    }

    static func wrap(_ size: CGSize) -> AXValue? {
        var size = size
        return unsafe AXValueCreate(.cgSize, &size)
    }

    @Test func readsTheFrameFromPositionAndSizeValues() throws {
        let position = try #require(Self.wrap(CGPoint(x: -1_440, y: 25)))
        let size = try #require(Self.wrap(CGSize(width: 800, height: 600)))
        #expect(
            FocusedWindow.frame(position: position, size: size)
                == CGRect(x: -1_440, y: 25, width: 800, height: 600))
    }

    @Test func rejectsValuesOfTheWrongKind() throws {
        let position = try #require(Self.wrap(CGPoint(x: 10, y: 20)))
        let size = try #require(Self.wrap(CGSize(width: 800, height: 600)))
        #expect(FocusedWindow.frame(position: size, size: position) == nil)
        #expect(FocusedWindow.frame(position: "AXPosition" as CFString, size: size) == nil)
    }

    @Test func mapsAccessibilityErrors() {
        #expect(FocusedWindow.failure(.apiDisabled) == .notAllowed)
        #expect(FocusedWindow.failure(.noValue) == .noWindow)
        #expect(FocusedWindow.failure(.attributeUnsupported) == .noWindow)
        #expect(FocusedWindow.failure(.invalidUIElement) == .noWindow)
        #expect(FocusedWindow.failure(.cannotComplete) == .failed(.cannotComplete))
    }

    @Test func keepsMovingWhenTheWindowRefusesAnAttribute() {
        #expect(FocusedWindow.refusal(.failure))
        #expect(FocusedWindow.refusal(.attributeUnsupported))
        #expect(FocusedWindow.refusal(.illegalArgument))
        #expect(!FocusedWindow.refusal(.cannotComplete))
        #expect(!FocusedWindow.refusal(.invalidUIElement))
        #expect(!FocusedWindow.refusal(.apiDisabled))
    }
}
