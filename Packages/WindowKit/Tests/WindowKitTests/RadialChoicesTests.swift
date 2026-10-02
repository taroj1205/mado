import Testing

@testable import WindowKit

@Suite struct RadialChoicesTests {
    @Test func theSettingsListOffersEveryActionOnce() {
        let listed = RadialSettings.groups.flatMap(\.actions)
        #expect(listed.count == RadialSettings.Action.allCases.count)
        #expect(Set(listed) == Set(RadialSettings.Action.allCases))
    }

    @Test func onlyTheCyclesCarryTheCycleBadge() {
        let cycles = RadialSettings.Action.allCases.filter(\.isCycle)
        #expect(cycles == [.topCycle, .rightCycle, .bottomCycle, .leftCycle])
        #expect(cycles.allSatisfy { $0.detail == "½ → ⅓ → ⅔" })
    }
}
