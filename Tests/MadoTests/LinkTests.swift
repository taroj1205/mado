import Testing

import AppCore
import GlassUI
import InputKit
import WindowKit
import SearchKit
import ClipboardKit

@Test func allPackagesLinkIntoTheTestBundle() {
    #expect(AppCoreModule.moduleName == "AppCore")
    #expect(GlassUIModule.moduleName == "GlassUI")
    #expect(InputKitModule.moduleName == "InputKit")
    #expect(WindowKitModule.moduleName == "WindowKit")
    #expect(SearchKitModule.moduleName == "SearchKit")
    #expect(ClipboardKitModule.moduleName == "ClipboardKit")
}
