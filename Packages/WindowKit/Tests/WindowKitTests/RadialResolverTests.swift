import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct RadialResolverTests {
    static let origin = CGPoint(x: 700, y: 400)
    static let far: CGFloat = 100

    static func zones(_ path: [(distance: CGFloat, degrees: CGFloat)]) -> [RadialResolver.Zone] {
        var resolver = RadialResolver(origin: origin)
        return path.map { step in
            let angle = step.degrees * .pi / 180
            resolver.update(
                pointer: CGPoint(
                    x: origin.x + step.distance * cos(angle),
                    y: origin.y + step.distance * sin(angle)))
            return resolver.zone
        }
    }

    @Test func startsInTheHole() {
        #expect(RadialResolver(origin: Self.origin).zone == .cancel)
    }

    @Test func leavesTheHoleAt28AndReturnsBelow24() {
        let path: [(CGFloat, CGFloat)] = [
            (27.9, 0), (28, 0), (27.9, 0), (28, 0), (24, 0), (23.9, 0), (27.9, 0), (24, 0),
        ]
        #expect(
            Self.zones(path) == [.cancel, .ring, .ring, .ring, .ring, .cancel, .cancel, .cancel])
    }

    @Test func leavesTheRingPast62AndReturnsAt58() {
        let path: [(CGFloat, CGFloat)] = [
            (62, 0), (62.1, 0), (61, 0), (58.1, 0), (58, 0), (61, 0), (62, 0), (62.1, 0),
        ]
        #expect(
            Self.zones(path) == [
                .ring, .direction(.right), .direction(.right), .direction(.right), .ring, .ring,
                .ring, .direction(.right),
            ])
    }

    @Test func pointsEachSectorAtItsDirectionWithYUp() {
        let sectors: [(CGFloat, RadialResolver.Direction)] = [
            (0, .right), (45, .topRight), (90, .top), (135, .topLeft), (180, .left),
            (225, .bottomLeft), (270, .bottom), (315, .bottomRight),
        ]
        for (degrees, direction) in sectors {
            #expect(Self.zones([(Self.far, degrees)]) == [.direction(direction)])
        }
    }

    @Test func holdsADirectionUntil6DegreesPastTheBoundary() {
        let path: [(CGFloat, CGFloat)] = [
            (Self.far, 21), (Self.far, 24), (Self.far, 21), (Self.far, 28), (Self.far, 29),
            (Self.far, 21), (Self.far, 17), (Self.far, 16), (Self.far, 24),
        ]
        #expect(
            Self.zones(path) == [
                .direction(.right), .direction(.right), .direction(.right), .direction(.right),
                .direction(.topRight), .direction(.topRight), .direction(.topRight),
                .direction(.right), .direction(.right),
            ])
    }

    @Test func holdsADirectionAcrossTheWraparound() {
        let path: [(CGFloat, CGFloat)] = [
            (Self.far, 0), (Self.far, -28), (Self.far, 334), (Self.far, -29),
            (Self.far, 343), (Self.far, 16),
        ]
        #expect(
            Self.zones(path) == [
                .direction(.right), .direction(.right), .direction(.right),
                .direction(.bottomRight), .direction(.bottomRight), .direction(.right),
            ])
    }

    @Test func picksTheNearestDirectionAfterReturningThroughTheRing() {
        let path: [(CGFloat, CGFloat)] = [(Self.far, 0), (40, 0), (Self.far, 24)]
        #expect(Self.zones(path) == [.direction(.right), .ring, .direction(.topRight)])
    }

    @Test func jumpsStraightFromTheHoleToADirection() {
        #expect(Self.zones([(10, 0), (Self.far, 180)]) == [.cancel, .direction(.left)])
    }

    @Test func givesEachDirectionTheAngleOfItsSector() {
        let directions: [RadialResolver.Direction] = [
            .right, .topRight, .top, .topLeft, .left, .bottomLeft, .bottom, .bottomRight,
        ]
        #expect(directions.map(\.degrees) == [0, 45, 90, 135, 180, 225, 270, 315])
    }

    @Test func countsStepsUntilTheZoneChanges() {
        var resolver = RadialResolver(origin: Self.origin)
        resolver.update(pointer: CGPoint(x: Self.origin.x - Self.far, y: Self.origin.y))
        resolver.advanceStep()
        resolver.advanceStep()
        resolver.update(pointer: CGPoint(x: Self.origin.x - Self.far - 20, y: Self.origin.y + 5))
        #expect(resolver.zone == .direction(.left))
        #expect(resolver.step == 2)

        resolver.update(pointer: CGPoint(x: Self.origin.x, y: Self.origin.y + Self.far))
        #expect(resolver.zone == .direction(.top))
        #expect(resolver.step == 0)

        resolver.advanceStep()
        resolver.update(pointer: CGPoint(x: Self.origin.x, y: Self.origin.y + 40))
        #expect(resolver.zone == .ring)
        #expect(resolver.step == 0)
    }
}
