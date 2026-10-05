import CoreGraphics
import Testing

@testable import InputKit

@Suite struct TrackpadSwipeTests {
    final class Recorder {
        static let middle: CGFloat = 0.5
        static let spread: CGFloat = 0.1

        var swipe = TrackpadSwipe(fingers: 3)
        var events: [SwitcherKeys.Event] = []

        func touch(_ count: Int, across: CGFloat) {
            touch(count, across: across, down: Self.middle)
        }

        func touch(_ count: Int, across: CGFloat, down: CGFloat) {
            let points = (0..<count).map { finger in
                CGPoint(x: across + CGFloat(finger) * Self.spread, y: down)
            }
            swipe.handle(points) { events.append($0) }
        }

        func lift() {
            swipe.handle([]) { events.append($0) }
        }
    }

    static let step = TrackpadSwipe.stepDistance * 1.1

    @Test func swipingRightOpensForwardAndLiftingChooses() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.step)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func swipingLeftOpensBackward() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.5)
        recorder.touch(3, across: 0.5 - Self.step)
        #expect(recorder.events == [.stepped(backward: true)])
    }

    @Test func eachFurtherStepMovesTheSelection() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: 0.2 + Self.step)
        recorder.touch(3, across: 0.2 + Self.step * 2)
        recorder.touch(3, across: 0.2 + Self.step)
        #expect(
            recorder.events == [
                .stepped(backward: false), .stepped(backward: false), .stepped(backward: true),
            ])
    }

    @Test func aShortMoveOrALiftWithoutASwipeDoesNothing() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.step / 2)
        recorder.lift()
        #expect(recorder.events.isEmpty)
    }

    @Test func liftingOneFingerChoosesBeforeTheRestAreUp() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.step)
        recorder.touch(2, across: 0.3 + Self.step)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func aVerticalSwipeIsLeftToMacOSUntilTheFingersLift() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3, down: 0.3)
        recorder.touch(3, across: 0.3, down: 0.3 + Self.step)
        recorder.touch(3, across: 0.3 + Self.step * 3, down: 0.3 + Self.step)
        #expect(recorder.events.isEmpty)

        recorder.lift()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.step)
        #expect(recorder.events == [.stepped(backward: false)])
    }

    @Test func upAndDownAfterOpeningMoveByRows() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3, down: 0.3)
        recorder.touch(3, across: 0.3 + Self.step, down: 0.3)
        recorder.touch(3, across: 0.3 + Self.step, down: 0.3 + Self.step)
        recorder.touch(3, across: 0.3 + Self.step, down: 0.3)
        recorder.touch(3, across: 0.3 + Self.step * 2, down: 0.3)
        #expect(
            recorder.events == [
                .stepped(backward: false), .steppedRow(upward: true), .steppedRow(upward: false),
                .stepped(backward: false),
            ])
    }

    @Test func moreFingersThanSetAreLeftToMacOS() {
        let recorder = Recorder()
        recorder.touch(4, across: 0.2)
        recorder.touch(4, across: 0.2 + Self.step)
        recorder.touch(3, across: 0.2 + Self.step)
        recorder.touch(3, across: 0.2 + Self.step * 3)
        #expect(recorder.events.isEmpty)
    }

    @Test func anExtraFingerDuringASwipeCancelsInsteadOfChoosing() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: 0.2 + Self.step)
        recorder.touch(4, across: 0.2 + Self.step)
        recorder.touch(4, across: 0.2 + Self.step * 3)
        recorder.touch(3, across: 0.2 + Self.step * 3)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .cancelled])
    }

    @Test func aFourFingerSwipeTriggersWhenSetToFour() {
        let recorder = Recorder()
        recorder.swipe = TrackpadSwipe(fingers: 4)
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: 0.2 + Self.step)
        recorder.touch(4, across: 0.2 + Self.step)
        recorder.touch(4, across: 0.2 + Self.step * 2)
        #expect(recorder.events == [.stepped(backward: false)])
    }
}
