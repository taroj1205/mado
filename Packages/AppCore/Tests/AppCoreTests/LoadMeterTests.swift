import Testing

@testable import AppCore

@Suite struct LoadMeterTests {
    private let start = ContinuousClock.now
    private var meter = LoadMeter()

    @Test mutating func theFirstReadingOnlySetsTheBaseline() {
        meter.record(.init(busy: 100, idle: 900, received: 5_000), at: start)
        #expect(meter.cpu == nil)
        #expect(meter.download == nil)
    }

    @Test mutating func loadAndSpeedComeFromTheChangeSinceTheLastReading() {
        meter.record(.init(busy: 100, idle: 900, received: 5_000), at: start)
        meter.record(.init(busy: 130, idle: 970, received: 9_000), at: start + .seconds(2))
        #expect(meter.cpu == 0.3)
        #expect(meter.download == 2_000)
        meter.record(.init(busy: 130, idle: 1_070, received: 9_000), at: start + .seconds(4))
        #expect(meter.cpu == 0)
        #expect(meter.download == 0)
    }

    @Test mutating func tickCountersThatWrapStillGiveTheLoad() {
        meter.record(.init(busy: .max - 9, idle: .max - 29, received: 0), at: start)
        meter.record(.init(busy: 10, idle: 50, received: 0), at: start + .seconds(1))
        #expect(meter.cpu == 0.2)
    }

    @Test mutating func aReadingRightAfterTheLastOneWaitsForMoreTime() {
        meter.record(.init(busy: 0, idle: 0, received: 0), at: start)
        meter.record(.init(busy: 1, idle: 0, received: 10), at: start + .milliseconds(5))
        #expect(meter.cpu == nil)
        meter.record(.init(busy: 50, idle: 50, received: 1_000), at: start + .seconds(1))
        #expect(meter.cpu == 0.5)
        #expect(meter.download == 1_000)
    }

    @Test mutating func aReadingAfterALongGapKeepsTheOldValuesAndStartsOver() {
        meter.record(.init(busy: 0, idle: 0, received: 0), at: start)
        meter.record(.init(busy: 25, idle: 75, received: 500), at: start + .seconds(1))
        meter.record(.init(busy: 9_025, idle: 75, received: 900_500), at: start + .seconds(3_600))
        #expect(meter.cpu == 0.25)
        #expect(meter.download == 500)
        meter.record(.init(busy: 9_025, idle: 175, received: 900_600), at: start + .seconds(3_601))
        #expect(meter.cpu == 0)
        #expect(meter.download == 100)
    }

    @Test mutating func aByteCounterThatDropsReadsAsNoTraffic() {
        meter.record(.init(busy: 0, idle: 0, received: 8_000), at: start)
        meter.record(.init(busy: 0, idle: 0, received: 3_000), at: start + .seconds(1))
        #expect(meter.cpu == nil)
        #expect(meter.download == 0)
    }
}
