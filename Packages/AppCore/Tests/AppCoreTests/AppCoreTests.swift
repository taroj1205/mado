import Testing

@testable import AppCore

@Test func appCoreLinks() {
    #expect(AppCoreModule.moduleName == "AppCore")
    #expect(AppCoreModule.dependsOn == [])
}
