import Testing

@testable import GlassUI

@Test func glassUILinks() {
    #expect(GlassUIModule.moduleName == "GlassUI")
    #expect(GlassUIModule.dependsOn == ["AppCore"])
}
