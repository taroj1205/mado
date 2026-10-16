import Testing

@testable import AppCore

@MainActor
@Suite struct CameraSessionTests {
    private let session = CameraSession()

    @Test func theCameraStaysInUseUntilTheLastUserReleasesIt() {
        session.retain()
        session.retain()
        session.release()
        #expect(session.isInUse)
        session.release()
        #expect(!session.isInUse)
    }

    @Test func releasingMoreThanRetainedLeavesItIdle() {
        session.release()
        session.retain()
        #expect(session.isInUse)
        session.release()
        #expect(!session.isInUse)
    }
}
