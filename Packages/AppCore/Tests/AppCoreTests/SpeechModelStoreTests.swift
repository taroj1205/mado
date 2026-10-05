import Foundation
import os
import Testing

@testable import AppCore

@Suite struct SpeechModelStoreTests {
    private let root = FileManager.default.temporaryDirectory.appending(
        path: "SpeechModelStoreTests-\(UUID().uuidString)")
    private let contents = Data("not really a model".utf8)

    private var store: SpeechModelStore {
        SpeechModelStore(directory: root.appending(path: "Models"))
    }

    private func source() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "source.bin")
        try contents.write(to: file)
        return file
    }

    private func model(sha256: String) throws -> SpeechModel {
        try SpeechModel(file: "ggml-tiny.bin", size: Int64(contents.count), sha256: sha256)
    }

    private func install(_ model: SpeechModel) throws {
        try FileManager.default.createDirectory(
            at: store.directory, withIntermediateDirectories: true)
        try Data().write(to: store.location(of: model))
    }

    private func download(_ model: SpeechModel, from url: URL) async throws -> [Double] {
        let steps = OSAllocatedUnfairLock(initialState: [Double]())
        try await store.download(model, from: url) { step in steps.withLock { $0.append(step) } }
        return steps.withLock { $0 }
    }

    @Test func aDownloadMatchingItsHashIsInstalled() async throws {
        let model = try model(
            sha256: "29a6a9f19463c8e9c592d2f06fa009fe46e351b618667e95eac63df77c56f404")
        #expect(try await download(model, from: source()) == [1])
        #expect(store.isInstalled(model))
        #expect(try Data(contentsOf: store.location(of: model)) == contents)
        let values = try store.location(of: model).resourceValues(forKeys: [
            .isExcludedFromBackupKey
        ])
        #expect(values.isExcludedFromBackup == true)
        try store.delete(model)
        #expect(!store.isInstalled(model))
    }

    @Test func aDownloadWithAnotherHashIsNotInstalled() async throws {
        let model = try model(sha256: String(repeating: "0", count: 64))
        await #expect(throws: SpeechModelStore.Failure.corrupt) {
            try await download(model, from: source())
        }
        #expect(!store.isInstalled(model))
    }

    @Test func aMissingSourceIsNotInstalled() async throws {
        let model = try model(sha256: "")
        await #expect(throws: (any Error).self) {
            try await download(model, from: root.appending(path: "missing.bin"))
        }
        #expect(!store.isInstalled(model))
    }

    @Test func thePreferredModelIsUsedWhileInstalled() throws {
        let small = try #require(SpeechModel.all.first { $0.id == "small" })
        let turbo = try #require(SpeechModel.all.first { $0.id == "large-v3-turbo" })
        #expect(store.model(preferring: turbo.id) == nil)
        try install(small)
        #expect(store.model(preferring: turbo.id) == small)
        #expect(store.model(preferring: nil) == small)
        try install(turbo)
        #expect(store.model(preferring: turbo.id) == turbo)
        try store.delete(turbo)
        #expect(store.model(preferring: turbo.id) == small)
    }

    @Test func theCatalogListsEveryWhisperFile() {
        let all = SpeechModel.all
        #expect(all.count == 33)
        #expect(Set(all.map(\.name)).count == all.count)
        #expect(all.allSatisfy { $0.sha256.count == 64 && $0.size > 0 })
        #expect(all.filter(\.isRecommended).map(\.id) == ["large-v3-turbo"])
        #expect(all.filter(\.isMeasured).map(\.id) == ["large-v3-turbo", "small"])
        #expect(all.first?.isRecommended == true)
    }

    @Test func aFileNameGivesTheModelItsNameAndRatings() throws {
        let english = try SpeechModel(file: "ggml-small.en-q5_1.bin", size: 1, sha256: "")
        #expect(english.id == "small.en-q5_1")
        #expect(english.name == "Whisper Small English Q5")
        #expect(english.isEnglishOnly && english.isCompressed && !english.isMeasured)
        #expect(english.languages == 1)
        #expect(english.accuracy == .low)
        #expect(english.memory == nil)
        #expect(english.isFiveBit)
        #expect(
            english.summary
                == "Fast. Good for English, weaker in Japanese. English only. "
                + "A third of the size, slightly less accurate.")
        let turbo = try SpeechModel(file: "ggml-large-v3-turbo-q8_0.bin", size: 1, sha256: "")
        #expect(turbo.name == "Whisper Large v3 Turbo Q8")
        #expect(turbo.accuracy == .highest && turbo.languages == 100 && !turbo.isRecommended)
        #expect(!turbo.isFiveBit && turbo.summary.hasSuffix("much faster. Half the size."))
        let full = try SpeechModel(file: "ggml-large-v3-turbo.bin", size: 1, sha256: "")
        #expect(full.memory == 1_900_000_000 && full.speed == .medium)
        #expect(throws: (any Error).self) {
            try SpeechModel(file: "ggml-huge.bin", size: 1, sha256: "")
        }
    }

    @Test func everyModelIsPinnedToARevision() throws {
        for model in SpeechModel.all {
            let url = try #require(model.url)
            #expect(url.host() == "huggingface.co")
            #expect(url.lastPathComponent == model.file)
            #expect(url.pathComponents.contains("5359861c739e955e79d9a303bcbc70fb988958b1"))
        }
        #expect(Set(SpeechModel.all.map(\.id)).count == SpeechModel.all.count)
    }
}
