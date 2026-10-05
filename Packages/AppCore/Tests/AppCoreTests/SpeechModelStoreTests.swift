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

    @Test func theCatalogListsEveryWhisperFileAndBothParakeetModels() {
        let all = SpeechModel.all
        let whisper = all.filter { $0.engine == .whisper }
        #expect(whisper.count == 33 && all.count == 35)
        #expect(Set(all.map(\.name)).count == all.count)
        #expect(whisper.allSatisfy { $0.sha256?.count == 64 && $0.size > 0 })
        #expect(all.filter(\.isRecommended).map(\.id) == ["large-v3-turbo"])
        #expect(
            Set(all.filter(\.isMeasured).map(\.id))
                == ["large-v3-turbo", "small", "parakeet-tdt-v3", "parakeet-tdt-ja"])
        #expect(all.first?.isRecommended == true)
    }

    @Test func parakeetModelsAreFoldersThatAreFastAndLight() throws {
        let parakeet = SpeechModel.all.filter { $0.engine == .parakeet }
        #expect(parakeet.map(\.id) == ["parakeet-tdt-v3", "parakeet-tdt-ja"])
        #expect(parakeet.allSatisfy { $0.url == nil && $0.speed == .highest && !$0.isEnglishOnly })
        let turbo = try #require(SpeechModel.all.first { $0.id == "large-v3-turbo" })
        #expect(parakeet.allSatisfy { ($0.memory ?? .max) < (turbo.memory ?? 0) })
        #expect(parakeet.map(\.file) == ["parakeet-tdt-0.6b-v3", "parakeet-ja"])
        #expect(parakeet.map(\.isJapaneseOnly) == [false, true])
        #expect(parakeet.map(\.languages) == [25, 1])
        #expect(turbo.advantage(over: parakeet[0]) == "more accurate")
    }

    @Test func aFolderModelIsInstalledOnlyOnceItIsWhole() async throws {
        let model = try #require(SpeechModel.all.first { $0.id == "parakeet-tdt-ja" })
        await #expect(throws: CocoaError.self) {
            try await store.install(model) { root, folder in
                try FileManager.default.createDirectory(
                    at: root.appending(path: folder), withIntermediateDirectories: true)
                throw CocoaError(.fileReadUnknown)
            }
        }
        #expect(!store.isInstalled(model))
        try await store.install(model) { root, folder in
            let target = root.appending(path: folder)
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            try contents.write(to: target.appending(path: "vocab.json"))
        }
        #expect(store.isInstalled(model))
        #expect(
            try Data(contentsOf: store.location(of: model).appending(path: "vocab.json"))
                == contents)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: store.directory.path()).count == 1)
        try store.delete(model)
        #expect(!store.isInstalled(model))
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
                == "Small for English only, compressed to a third of the size and slightly less "
                + "accurate.")
        let turbo = try SpeechModel(file: "ggml-large-v3-turbo-q8_0.bin", size: 1, sha256: "")
        #expect(turbo.name == "Whisper Large v3 Turbo Q8")
        #expect(turbo.accuracy == .highest && turbo.languages == 100 && !turbo.isRecommended)
        #expect(!turbo.isFiveBit && turbo.summary == "Large v3 Turbo, compressed to half the size.")
        let full = try SpeechModel(file: "ggml-large-v3-turbo.bin", size: 1, sha256: "")
        #expect(full.memory == 1_900_000_000 && full.speed == .medium)
        let englishSmall = try SpeechModel(file: "ggml-small.en.bin", size: 1, sha256: "")
        #expect(englishSmall.summary == "Small for English only. It can’t transcribe Japanese.")
    }

    @Test func aTipOnlyClaimsWhatTheRatingsShow() throws {
        let model = { (file: String) in try SpeechModel(file: file, size: 1, sha256: "") }
        let turbo = try model("ggml-large-v3-turbo.bin")
        #expect(try turbo.advantage(over: model("ggml-small.bin")) == "more accurate")
        #expect(try turbo.advantage(over: model("ggml-large-v3.bin")) == "as accurate and faster")
        #expect(try turbo.advantage(over: model("ggml-medium.bin")) == "more accurate and faster")
        #expect(try turbo.advantage(over: model("ggml-tiny.bin")) == "more accurate")
        #expect(turbo.advantage(over: turbo) == nil)
        #expect(try turbo.advantage(over: model("ggml-large-v3-turbo-q8_0.bin")) == nil)
        #expect(throws: (any Error).self) {
            try SpeechModel(file: "ggml-huge.bin", size: 1, sha256: "")
        }
    }

    @Test func everyModelIsPinnedToARevision() throws {
        for model in SpeechModel.all where model.engine == .whisper {
            let url = try #require(model.url)
            #expect(url.host() == "huggingface.co")
            #expect(url.lastPathComponent == model.file)
            #expect(url.pathComponents.contains("5359861c739e955e79d9a303bcbc70fb988958b1"))
        }
        #expect(Set(SpeechModel.all.map(\.id)).count == SpeechModel.all.count)
    }
}
