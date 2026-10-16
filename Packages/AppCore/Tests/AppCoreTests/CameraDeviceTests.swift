import Testing

@testable import AppCore

@Suite struct CameraDeviceTests {
    private let builtIn = CameraDevice(id: "built-in", name: "FaceTime HD Camera")
    private let phone = CameraDevice(id: "phone", name: "iPhone Camera")
    private let webcam = CameraDevice(id: "webcam", name: "Brio")

    @Test func triesTheCameraTheUserPickedLastTimeFirst() {
        let order = CameraDevice.ordered(
            from: [builtIn, phone, webcam], saved: "webcam", preferred: "phone")
        #expect(order == [webcam, phone, builtIn])
    }

    @Test func followsTheSystemChoiceWhenNothingWasSaved() {
        let order = CameraDevice.ordered(
            from: [builtIn, phone, webcam], saved: nil, preferred: "phone")
        #expect(order == [phone, builtIn, webcam])
    }

    @Test func skipsASavedCameraThatIsUnplugged() {
        let order = CameraDevice.ordered(
            from: [builtIn, phone], saved: "webcam", preferred: "phone")
        #expect(order == [phone, builtIn])
    }

    @Test func keepsTheListOrderWhenNeitherCameraIsThere() {
        let order = CameraDevice.ordered(
            from: [builtIn, phone], saved: "webcam", preferred: "gone")
        #expect(order == [builtIn, phone])
    }

    @Test func hasNoCameraToTryWhenTheListIsEmpty() {
        #expect(CameraDevice.ordered(from: [], saved: "webcam", preferred: "phone").isEmpty)
    }
}
