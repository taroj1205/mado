import Foundation
import Testing

@testable import InputKit

@Suite struct RemapLockTests {
    private static func url() -> URL {
        URL.temporaryDirectory.appending(path: "RemapLockTests-\(UUID().uuidString).lock")
    }

    @Test func onlyOneHolderAtATime() throws {
        let url = Self.url()
        defer { try? FileManager.default.removeItem(at: url) }
        let first = try #require(RemapLock(url: url))
        let second = try #require(RemapLock(url: url))

        #expect(first.acquire())
        #expect(!second.acquire())
        first.release()
        #expect(second.acquire())
    }

    @Test func aChildGivenTheHandleKeepsTheLockAfterTheOwnerIsGone() throws {
        let url = Self.url()
        defer { try? FileManager.default.removeItem(at: url) }
        let owner = try #require(RemapLock(url: url))
        #expect(owner.acquire())
        let input = Pipe()
        let child = Process()
        child.executableURL = URL(filePath: "/bin/sh")
        child.arguments = ["-c", "read -r unused"]
        child.standardInput = input
        child.standardOutput = owner.handle
        try child.run()
        try owner.handle.close()
        let next = try #require(RemapLock(url: url))

        #expect(!next.acquire())
        try input.fileHandleForWriting.close()
        child.waitUntilExit()
        #expect(next.acquire())
    }
}
