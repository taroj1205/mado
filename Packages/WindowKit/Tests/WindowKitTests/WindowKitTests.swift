import Testing

@testable import WindowKit

@Test func windowKitLinks() {
    #expect(WindowKitModule.moduleName == "WindowKit")
    #expect(WindowKitModule.dependsOn == ["AppCore"])
}
