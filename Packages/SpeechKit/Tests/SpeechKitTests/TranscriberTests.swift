import Foundation
import Testing

@testable import SpeechKit

@Suite struct TranscriberTests {
    @Test func segmentsJoinIntoOneTrimmedLine() {
        #expect(
            Transcriber.text([" Running ten minutes late,", " save me a seat."])
                == "Running ten minutes late, save me a seat.")
        #expect(
            Transcriber.text(["十分遅れます。", "席を取っておいてください。"])
                == "十分遅れます。席を取っておいてください。")
    }

    @Test func soundAnnotationsAreLeftOut() {
        #expect(Transcriber.text([" [BLANK_AUDIO]"]).isEmpty)
        #expect(Transcriber.text([" [Music]", " Hello."]) == "Hello.")
    }

    @Test func bracketsInsideSpeechStay() {
        #expect(Transcriber.text([" Save it as [draft] for now."]) == "Save it as [draft] for now.")
    }

    @Test func aMissingModelFailsToLoad() async {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-model.bin")
        await #expect(throws: Transcriber.Failure.self) {
            try await Transcriber().transcribe(Array(repeating: 0, count: 16_000), with: missing)
        }
    }

    @Test func audioTooShortToHoldAWordIsEmpty() async throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-model.bin")
        #expect(
            try await Transcriber().transcribe(Array(repeating: 0, count: 800), with: missing)
                .isEmpty)
    }
}
