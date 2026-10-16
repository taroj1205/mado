import Testing

@testable import AppCore

@Suite struct CameraDeviceTests {
    private let builtIn = CameraDevice(id: "built-in", name: "FaceTime HD Camera")
    private let phone = CameraDevice(id: "phone", name: "iPhone Camera")
    private let webcam = CameraDevice(id: "webcam", name: "Brio")

    @Test func keepsTheCameraTheUserPickedLastTime() {
        let chosen = CameraDevice.choose(
            from: [builtIn, phone, webcam], saved: "webcam", preferred: "phone")
        #expect(chosen == webcam)
    }

    @Test func followsTheSystemChoiceWhenNothingWasSaved() {
        let chosen = CameraDevice.choose(
            from: [builtIn, phone, webcam], saved: nil, preferred: "phone")
        #expect(chosen == phone)
    }

    @Test func skipsASavedCameraThatIsUnplugged() {
        let chosen = CameraDevice.choose(
            from: [builtIn, phone], saved: "webcam", preferred: "phone")
        #expect(chosen == phone)
    }

    @Test func fallsBackToTheFirstCamera() {
        let chosen = CameraDevice.choose(
            from: [builtIn, phone], saved: "webcam", preferred: "gone")
        #expect(chosen == builtIn)
    }

    @Test func hasNoCameraWhenTheListIsEmpty() {
        #expect(CameraDevice.choose(from: [], saved: "webcam", preferred: "phone") == nil)
    }
}
