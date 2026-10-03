import Foundation
import Testing

@testable import GlassUI

@MainActor
@Suite struct DictationMeterTests {
    @Test func theTimeCountsWholeSeconds() {
        #expect(DictationPill.timeText(.zero) == "0:00")
        #expect(DictationPill.timeText(.milliseconds(59_999)) == "0:59")
        #expect(DictationPill.timeText(.seconds(65)) == "1:05")
    }

    @Test func barsScaleFromSilenceToFullLevel() {
        #expect(DictationMeter.height(rms: 0) == 6)
        #expect(DictationMeter.height(rms: pow(10, -60 / 20)) == 6)
        #expect(DictationMeter.height(rms: pow(10, -25 / 20)) == 15)
        #expect(DictationMeter.height(rms: 1) == 24)
        #expect(DictationMeter.height(rms: 4) == 24)
    }

    @Test func newLevelsEnterOnTheRight() {
        let meter = DictationMeter()
        meter.push(1)
        meter.push(0)
        #expect(meter.heights.count == DictationMeter.bars)
        #expect(meter.heights.suffix(2) == [24, 6])
        meter.reset()
        #expect(meter.heights.allSatisfy { $0 == 6 })
    }
}
