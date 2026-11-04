import CoreGraphics
import Testing

@testable import InputKit

@Suite struct TrackpadSwipeTests {
    final class Recorder {
        static let middle: CGFloat = 150
        static let spread: CGFloat = 30

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

    static let open = TrackpadSwipe.openDistance * 1.1
    static let step = TrackpadSwipe.stepDistance * 1.1

    @Test func swipingRightOpensForwardAndLiftingChooses() {
        let recorder = Recorder()
        recorder.touch(3, across: 150)
        recorder.touch(3, across: 150 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func swipingLeftOpensBackward() {
        let recorder = Recorder()
        recorder.touch(3, across: 250)
        recorder.touch(3, across: 250 - Self.open)
        #expect(recorder.events == [.stepped(backward: true)])
    }

    @Test func eachFurtherStepMovesTheSelection() {
        let recorder = Recorder()
        let opened = 100 + Self.open
        recorder.touch(3, across: 100)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + Self.step)
        recorder.touch(3, across: opened)
        #expect(
            recorder.events == [
                .stepped(backward: false), .stepped(backward: false), .stepped(backward: true),
            ])
    }

    @Test func aWobbleAsLongAsAStepOrALiftWithoutASwipeDoesNothing() {
        let recorder = Recorder()
        recorder.touch(3, across: 150)
        recorder.touch(3, across: 150 + Self.step)
        recorder.lift()
        #expect(recorder.events.isEmpty)
    }

    @Test func aFastSwipeStepsOnceForEveryStepItCoversAndKeepsTheRest() {
        let recorder = Recorder()
        let opened = 100 + Self.open
        recorder.touch(3, across: 100)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + TrackpadSwipe.stepDistance * 2.5)
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 3))
        recorder.touch(3, across: opened + TrackpadSwipe.stepDistance * 3.1)
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 4))
    }

    @Test func driftingDownWhileSwipingAcrossDoesNotMoveRows() {
        let recorder = Recorder()
        let opened = 100 + Self.open
        recorder.touch(3, across: 100, down: 150)
        recorder.touch(3, across: opened, down: 150)
        for frame in 1...3 {
            let moved = CGFloat(frame)
            recorder.touch(
                3, across: opened + Self.step * moved, down: 150 - Self.step * 0.7 * moved)
        }
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 4))
    }

    @Test func liftingDownToOneFingerChooses() {
        let recorder = Recorder()
        recorder.touch(3, across: 150)
        recorder.touch(3, across: 150 + Self.open)
        recorder.touch(2, across: 150 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.touch(1, across: 150 + Self.open)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func aFingerSlippingOffMidSwipeNeitherChoosesNorJumps() {
        let recorder = Recorder()
        recorder.touch(3, across: 150)
        recorder.touch(3, across: 150 + Self.open)
        recorder.touch(2, across: 250)
        recorder.touch(3, across: 100)
        recorder.touch(3, across: 100 + Self.step / 2)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.touch(3, across: 100 + Self.step)
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: false)])
    }

    @Test func aVerticalSwipeIsLeftToMacOSUntilTheFingersLift() {
        let recorder = Recorder()
        recorder.touch(3, across: 150, down: 150)
        recorder.touch(3, across: 150, down: 150 + Self.open)
        recorder.touch(3, across: 150 + Self.open * 3, down: 150 + Self.open)
        #expect(recorder.events.isEmpty)

        recorder.lift()
        recorder.touch(3, across: 150)
        recorder.touch(3, across: 150 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
    }

    @Test func upAndDownAfterOpeningMoveByRows() {
        let recorder = Recorder()
        let opened = 150 + Self.open
        recorder.touch(3, across: 150, down: 150)
        recorder.touch(3, across: opened, down: 150)
        recorder.touch(3, across: opened, down: 150 + Self.step)
        recorder.touch(3, across: opened, down: 150)
        recorder.touch(3, across: opened + Self.step, down: 150)
        #expect(
            recorder.events == [
                .stepped(backward: false), .steppedRow(upward: true), .steppedRow(upward: false),
                .stepped(backward: false),
            ])
    }

    @Test func moreFingersThanSetAreLeftToMacOS() {
        let recorder = Recorder()
        recorder.touch(4, across: 100)
        recorder.touch(4, across: 100 + Self.open)
        recorder.touch(3, across: 100 + Self.open)
        recorder.touch(3, across: 100 + Self.open * 3)
        #expect(recorder.events.isEmpty)
    }

    @Test func anExtraFingerDuringASwipeCancelsInsteadOfChoosing() {
        let recorder = Recorder()
        recorder.touch(3, across: 100)
        recorder.touch(3, across: 100 + Self.open)
        recorder.touch(4, across: 100 + Self.open)
        recorder.touch(4, across: 100 + Self.open * 3)
        recorder.touch(3, across: 100 + Self.open * 3)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .cancelled])
    }

    @Test func aFourFingerSwipeTriggersWhenSetToFour() {
        let recorder = Recorder()
        recorder.swipe = TrackpadSwipe(fingers: 4)
        recorder.touch(3, across: 100)
        recorder.touch(3, across: 100 + Self.open)
        recorder.touch(4, across: 100 + Self.open)
        recorder.touch(4, across: 100 + Self.open * 2)
        #expect(recorder.events == [.stepped(backward: false)])
    }
}
