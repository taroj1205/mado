import CoreGraphics
import Testing

@testable import WindowKit

@Suite struct RadialCycleTests {
    @Test func aCycleStepsThroughHalfThirdAndTwoThirdsThenStartsOver() {
        let steps = (0..<4).map { RadialSettings.Action.leftCycle.layout(step: $0) }
        #expect(steps == [.leftHalf, .leftThird, .leftTwoThirds, .leftHalf])
        #expect(RadialSettings.Action.topCycle.layout(step: 1) == .topThird)
        #expect(RadialSettings.Action.rightCycle.layout(step: 2) == .rightTwoThirds)
        #expect(RadialSettings.Action.bottomCycle.layout(step: 2) == .bottomTwoThirds)
    }

    @Test func otherActionsIgnoreTheStep() {
        #expect(RadialSettings.Action.leftHalf.layout(step: 1) == .leftHalf)
        #expect(RadialSettings.Action.maximize.layout(step: 2) == .maximize)
        #expect(RadialSettings.Action.fullScreen.layout(step: 1) == nil)
    }

    @Test func onlyTheHalfStepFillsBesideAWindowThatRefusedItsHalf() {
        #expect(RadialSettings.Action.leftCycle.half(step: 0) == .left)
        #expect(RadialSettings.Action.leftCycle.half(step: 1) == nil)
        #expect(RadialSettings.Action.rightCycle.half(step: 3) == .right)
        #expect(RadialSettings.Action.topCycle.half(step: 0) == nil)
    }

    @Test func thePreviewFollowsTheStep() {
        let screen = ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 66, width: 1_440, height: 810))
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        let third = LayoutEngine.frame(
            for: .rightThird, in: screen.visibleFrame, gap: 12, windowSize: window.size)

        #expect(
            RadialSettings.Action.rightCycle.previewFrame(of: window, on: screen, gap: 12, step: 1)
                == third)
    }

    @Test func theLabelNamesWhatLettingGoWillDo() {
        var radial = RadialSettings()
        radial.bottomLeft = .nothing
        radial.bottomRight = .fullScreen

        #expect(radial.label(in: .cancel, step: 0) == "Cancel")
        #expect(radial.label(in: .direction(.bottomLeft), step: 0) == "Cancel")
        #expect(radial.label(in: .direction(.bottomRight), step: 0) == "macOS Full Screen")
        #expect(radial.label(in: .ring, step: 0) == "Maximize")
        #expect(radial.label(in: .direction(.topLeft), step: 0) == "Top Left Quarter")
        #expect(radial.label(in: .direction(.left), step: 0) == "Left Half")
        #expect(radial.label(in: .direction(.left), step: 1) == "Left Third")
        #expect(radial.label(in: .direction(.top), step: 2) == "Top Two Thirds")
    }
}
