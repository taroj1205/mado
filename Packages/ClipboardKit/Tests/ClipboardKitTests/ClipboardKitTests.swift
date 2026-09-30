import Testing

@testable import ClipboardKit

@Test func clipboardKitLinks() {
    #expect(ClipboardKitModule.moduleName == "ClipboardKit")
    #expect(ClipboardKitModule.dependsOn == ["AppCore", "InputKit"])
}
