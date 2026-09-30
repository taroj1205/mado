import Testing

@testable import SearchKit

@Test func searchKitLinks() {
    #expect(SearchKitModule.moduleName == "SearchKit")
    #expect(SearchKitModule.dependsOn == ["AppCore"])
}
