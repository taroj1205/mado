import Testing

@testable import InputKit

@Test func inputKitLinks() {
    #expect(InputKitModule.moduleName == "InputKit")
    #expect(InputKitModule.dependsOn == ["AppCore"])
}
