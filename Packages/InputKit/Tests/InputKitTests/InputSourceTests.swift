import Testing

@testable import InputKit

@MainActor
@Suite struct InputSourceTests {
    @Test func anInstalledSourceIsFoundByIDWithItsName() throws {
        let source = try #require(InputSource.installed(id: "com.apple.keylayout.US"))

        #expect(source.id == "com.apple.keylayout.US")
        #expect(source.name != source.id)
    }

    @Test func anUnknownIDFindsNothing() {
        #expect(InputSource.installed(id: "com.example.missing") == nil)
        #expect(!InputSource.select(id: "com.example.missing"))
    }
}
