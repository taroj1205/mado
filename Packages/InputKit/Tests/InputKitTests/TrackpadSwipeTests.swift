import AppKit
import Testing

@testable import InputKit

@Suite struct TrackpadSwipeTests {
    final class Recorder {
        static let middle: CGFloat = 0.5
        static let spread: CGFloat = 0.1

        var swipe = TrackpadSwipe(fingers: 3)
        var events: [SwitcherKeys.Event] = []
        private var positions: [Int: CGPoint] = [:]

        func touch(_ count: Int, across: CGFloat) {
            touch(count, across: across, down: Self.middle)
        }

        func touch(_ count: Int, across: CGFloat, down: CGFloat) {
            place(
                (0..<count).map { finger in
                    (finger, CGPoint(x: across + CGFloat(finger) * Self.spread, y: down))
                }, still: [])
        }

        func touch(_ fingers: Range<Int>, across: CGFloat, still: Set<Int>) {
            place(
                fingers.map { finger in
                    let moved = CGPoint(x: across + CGFloat(finger) * Self.spread, y: Self.middle)
                    let held = still.contains(finger)
                    return (finger, held ? positions[finger, default: moved] : moved)
                }, still: still)
        }

        func touch(at across: [CGFloat]) {
            place(across.enumerated().map { ($0, CGPoint(x: $1, y: Self.middle)) }, still: [])
        }

        private func place(_ placed: [(finger: Int, position: CGPoint)], still: Set<Int>) {
            let touches = placed.map { finger, position in
                let held: NSTouch.Phase = still.contains(finger) ? .stationary : .moved
                let phase = positions[finger] == nil ? .began : held
                return TrackpadSwipe.Touch(id: finger, position: position, phase: phase)
            }
            positions = Dictionary(uniqueKeysWithValues: placed.map { ($0, $1) })
            swipe.handle(touches) { events.append($0) }
        }

        func lift() {
            positions = [:]
            swipe.handle([]) { events.append($0) }
        }
    }

    static let open = TrackpadSwipe.openDistance * 1.1
    static let step = TrackpadSwipe.stepDistance * 1.1

    @Test func swipingRightOpensForwardAndLiftingChooses() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func swipingLeftOpensBackward() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.4)
        recorder.touch(3, across: 0.4 - Self.open)
        #expect(recorder.events == [.stepped(backward: true)])
    }

    @Test func eachFurtherStepMovesTheSelection() {
        let recorder = Recorder()
        let opened = 0.2 + Self.open
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + Self.step)
        recorder.touch(3, across: opened - TrackpadSwipe.stepDistance * 0.1)
        #expect(
            recorder.events == [
                .stepped(backward: false), .stepped(backward: false), .stepped(backward: true),
            ])
    }

    @Test func aWobbleShorterThanTheOpenDistanceOrALiftWithoutASwipeDoesNothing() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + TrackpadSwipe.openDistance * 0.9)
        recorder.lift()
        #expect(recorder.events.isEmpty)
    }

    @Test func fingersMovingApartDoNotOpen() {
        let recorder = Recorder()
        recorder.touch(at: [0.3, 0.4, 0.5])
        recorder.touch(at: [0.3 - Self.open, 0.4 + Self.open * 4, 0.5 + Self.open * 4])
        #expect(recorder.events.isEmpty)
    }

    @Test func aFastSwipeStepsOnceForEveryStepItCoversAndKeepsTheRest() {
        let recorder = Recorder()
        let opened = 0.2 + Self.open
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + TrackpadSwipe.stepDistance * 2.5)
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 3))
        recorder.touch(3, across: opened + TrackpadSwipe.stepDistance * 3.1)
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 4))
    }

    @Test func driftingDownWhileSwipingAcrossDoesNotMoveRows() {
        let recorder = Recorder()
        let opened = 0.2 + Self.open
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: opened)
        for frame in 1...3 {
            let moved = CGFloat(frame)
            recorder.touch(
                3, across: opened + Self.step * moved, down: 0.5 - Self.step * 0.7 * moved)
        }
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 4))
    }

    @Test func liftingDownToOneFingerChooses() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.open)
        recorder.touch(2, across: 0.3 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.touch(1, across: 0.3 + Self.open)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .chosen])
    }

    @Test func aFingerSlippingOffMidSwipeKeepsTheTravelAndComingBackDoesNotJump() {
        let recorder = Recorder()
        let opened = 0.2 + Self.open
        let halfStep = TrackpadSwipe.stepDistance * 0.55
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + halfStep)
        recorder.touch(2, across: opened + halfStep * 2)
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: false)])
        let back = opened + 0.2
        recorder.touch(3, across: back)
        recorder.touch(3, across: back + halfStep)
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: false)])
        recorder.touch(3, across: back + halfStep * 2)
        #expect(recorder.events == Array(repeating: .stepped(backward: false), count: 3))
    }

    @Test func aFingerPausingMidSwipeKeepsTheTravelSoFar() {
        let recorder = Recorder()
        let opened = 0.2 + Self.open
        let halfStep = TrackpadSwipe.stepDistance * 0.55
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: opened)
        recorder.touch(3, across: opened + halfStep)
        recorder.touch(0..<3, across: opened + halfStep * 2, still: [2])
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: false)])
    }

    @Test func aRestingThumbDoesNotStopTheSwipe() {
        let recorder = Recorder()
        recorder.touch(3..<4, across: 0.2, still: [])
        recorder.touch(0..<4, across: 0.2, still: [3])
        recorder.touch(0..<4, across: 0.2 + Self.open, still: [3])
        #expect(recorder.events == [.stepped(backward: false)])
        recorder.touch(0..<4, across: 0.2 + Self.open + Self.step, still: [3])
        #expect(recorder.events == [.stepped(backward: false), .stepped(backward: false)])
        recorder.touch(3..<4, across: 0.2, still: [3])
        #expect(
            recorder.events == [.stepped(backward: false), .stepped(backward: false), .chosen])
    }

    @Test func aVerticalSwipeIsLeftToMacOSUntilTheFingersLift() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.3, down: 0.5)
        recorder.touch(3, across: 0.3, down: 0.5 + Self.open)
        recorder.touch(3, across: 0.3 + Self.open * 3, down: 0.5 + Self.open)
        #expect(recorder.events.isEmpty)

        recorder.lift()
        recorder.touch(3, across: 0.3)
        recorder.touch(3, across: 0.3 + Self.open)
        #expect(recorder.events == [.stepped(backward: false)])
    }

    @Test func upAndDownAfterOpeningMoveByRows() {
        let recorder = Recorder()
        let opened = 0.3 + Self.open
        recorder.touch(3, across: 0.3, down: 0.5)
        recorder.touch(3, across: opened, down: 0.5)
        recorder.touch(3, across: opened, down: 0.5 + Self.step)
        recorder.touch(3, across: opened, down: 0.5 - TrackpadSwipe.stepDistance * 0.1)
        recorder.touch(3, across: opened + Self.step, down: 0.5)
        #expect(
            recorder.events == [
                .stepped(backward: false), .steppedRow(upward: true), .steppedRow(upward: false),
                .stepped(backward: false),
            ])
    }

    @Test func moreFingersThanSetAreLeftToMacOS() {
        let recorder = Recorder()
        recorder.touch(4, across: 0.2)
        recorder.touch(4, across: 0.2 + Self.open)
        recorder.touch(3, across: 0.2 + Self.open)
        recorder.touch(3, across: 0.2 + Self.open * 3)
        #expect(recorder.events.isEmpty)
    }

    @Test func anExtraFingerDuringASwipeCancelsInsteadOfChoosing() {
        let recorder = Recorder()
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: 0.2 + Self.open)
        recorder.touch(4, across: 0.2 + Self.open)
        recorder.touch(4, across: 0.2 + Self.open * 3)
        recorder.touch(3, across: 0.2 + Self.open * 3)
        recorder.lift()
        #expect(recorder.events == [.stepped(backward: false), .cancelled])
    }

    @Test func aFourFingerSwipeTriggersWhenSetToFour() {
        let recorder = Recorder()
        recorder.swipe = TrackpadSwipe(fingers: 4)
        recorder.touch(3, across: 0.2)
        recorder.touch(3, across: 0.2 + Self.open)
        recorder.touch(4, across: 0.2 + Self.open)
        recorder.touch(4, across: 0.2 + Self.open * 2)
        #expect(recorder.events == [.stepped(backward: false)])
    }
}
