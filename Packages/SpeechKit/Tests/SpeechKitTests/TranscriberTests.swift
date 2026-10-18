import Foundation
import Testing

@testable import SpeechKit

@Suite struct TranscriberTests {
    private static let tone = (0..<16_000).map { Float(0.1 * sin(Double($0) * 0.1)) }

    private func transcribe(_ samples: [Float], with model: URL) async throws -> String {
        try await Transcriber().transcribe(
            samples, with: model, languages: SpeechLanguages(), words: SpeechWords())
    }

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
            try await transcribe(Self.tone, with: missing)
        }
    }

    @Test func audioTooShortToHoldAWordIsEmpty() async throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-model.bin")
        #expect(
            try await transcribe(Array(repeating: 0, count: 800), with: missing)
                .isEmpty)
    }

    @Test func silenceIsEmptyWithoutLoadingTheModel() async throws {
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-model.bin")
        let hiss = (0..<16_000).map { Float(0.001 * sin(Double($0) * 0.1)) }
        let silent = [Float](repeating: 0, count: 16_000)
        #expect(try await transcribe(silent, with: missing).isEmpty)
        #expect(try await transcribe(hiss, with: missing).isEmpty)
    }

    @Test func aShortWordInLongSilenceIsSound() {
        var samples = [Float](repeating: 0, count: 48_000)
        samples.replaceSubrange(20_000..<21_600, with: Self.tone.prefix(1_600))
        #expect(Transcriber.hasSound(samples))
        #expect(!Transcriber.hasSound([]))
    }

    @Test func speechAfterTheLastFullWindowIsSound() {
        var samples = [Float](repeating: 0, count: 3_199)
        samples.replaceSubrange(1_700..<3_199, with: Self.tone.prefix(1_499))
        #expect(Transcriber.hasSound(samples))
    }

    @Test func parakeetModelsAreRecognisedByTheirFolderName() {
        #expect(Parakeet.version(folder: "parakeet-tdt-0.6b-v3") != nil)
        #expect(Parakeet.version(folder: "parakeet-ja") != nil)
        #expect(Parakeet.version(folder: "ggml-large-v3-turbo.bin") == nil)
    }

    @Test func aMissingParakeetFolderFailsToLoad() async {
        let missing = FileManager.default.temporaryDirectory.appending(path: "parakeet-ja")
        await #expect(throws: (any Error).self) {
            try await transcribe(Self.tone, with: missing)
        }
    }
}
