import Testing

@testable import InputKit

@MainActor
@Suite struct InputSourceTests {
    @Test func listsTheCurrentKeyboardSourceAmongTheEnabledOnes() throws {
        let current = try #require(InputSource.currentID)
        let source = try #require(InputSource.enabled.first { $0.id == current })

        #expect(!source.name.isEmpty)
        #expect(InputSource.named(current) == source.name)
    }

    @Test func ignoresASourceThatIsNotEnabled() throws {
        let current = try #require(InputSource.currentID)

        InputSource.select("com.example.not-a-source")

        #expect(InputSource.currentID == current)
        #expect(InputSource.named("com.example.not-a-source") == nil)
    }
}
