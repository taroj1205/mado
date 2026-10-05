import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct FilePreviewTests {
    private let launcher = CGRect(x: 100, y: 300, width: 760, height: 476)

    @Test func sitsRightOfTheLauncherAndCentredOnIt() {
        let frame = FilePreview.frame(
            beside: launcher, in: CGRect(x: 0, y: 0, width: 1_600, height: 1_000))
        #expect(frame == CGRect(x: 892, y: 268, width: 400, height: 540))
    }

    @Test func movesLeftWhenTheLeftHasMoreRoom() {
        let anchor = launcher.offsetBy(dx: 700, dy: 0)
        let frame = FilePreview.frame(
            beside: anchor, in: CGRect(x: 0, y: 0, width: 1_600, height: 1_000))
        #expect(frame.maxX == anchor.minX - FilePreview.gap)
        #expect(frame.width == FilePreview.width)
    }

    @Test func narrowsToTheRoomBesideACentredLauncherAndStaysOnScreen() {
        let visible = CGRect(x: 0, y: 0, width: 1_512, height: 900)
        let anchor = CGRect(x: 376, y: 300, width: 760, height: 476)
        let frame = FilePreview.frame(beside: anchor, in: visible)
        #expect(frame.minX == anchor.maxX + FilePreview.gap)
        #expect(frame.maxX == visible.maxX - FilePreview.edge)
        #expect(visible.contains(frame))
    }

    @Test func overlapsRatherThanLeavingTheScreenWhenThereIsNoRoom() {
        let visible = CGRect(x: 0, y: 0, width: 900, height: 500)
        let frame = FilePreview.frame(
            beside: CGRect(x: 70, y: 12, width: 760, height: 476), in: visible)
        #expect(frame.width == FilePreview.minimumWidth)
        #expect(visible.contains(frame))
    }

    @Test func showsKindSizeAndModifiedAndHidesSizeForAFolder() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "notes.txt")
        try Data(count: 2_048).write(to: file)
        let preview = FilePreview()
        defer { preview.close() }
        let visible = CGRect(x: 0, y: 0, width: 1_600, height: 1_000)

        preview.show(file, beside: launcher, in: visible)
        #expect(preview.title.stringValue == "notes.txt")
        #expect(!preview.kind.stringValue.isEmpty)
        #expect(
            preview.size.stringValue
                == ByteCountFormatter.string(fromByteCount: 2_048, countStyle: .file))
        #expect(!preview.sizeRow.isHidden)
        preview.panel.contentView?.layoutSubtreeIfNeeded()
        let row = preview.sizeRow.convert(preview.sizeRow.bounds, to: preview.panel.contentView)
        let value = preview.size.convert(preview.size.bounds, to: preview.panel.contentView)
        #expect(abs(row.maxX - value.maxX) <= 2)
        #expect(abs(row.width - (preview.panel.frame.width - 36)) < 1)
        #expect(
            preview.modified.stringValue.hasSuffix(
                Date.now.formatted(date: .omitted, time: .shortened)))

        preview.show(folder, beside: launcher, in: visible)
        #expect(preview.sizeRow.isHidden)
    }

    @Test func theOpenButtonRunsTheOpenAction() throws {
        let preview = FilePreview()
        var opens = 0
        preview.onOpen = { opens += 1 }
        let open = try #require(buttons(in: preview.panel.glass).first { $0.title == "Open" })
        open.performClick(nil)
        #expect(opens == 1)
        #expect(buttons(in: preview.panel.glass).map(\.title) == ["Open", "Share"])
        #expect(!preview.panel.ignoresMouseEvents)
        #expect(!preview.panel.canBecomeKey)
    }

    @Test func closingTheShareMenuReportsWhetherAServiceWasPicked() throws {
        let preview = FilePreview()
        var ends: [Bool] = []
        preview.onShareEnd = { ends.append($0) }
        let picker = NSSharingServicePicker(items: [])
        let service = try #require(NSSharingService(named: .sendViaAirDrop))
        preview.sharingServicePicker(picker, didChoose: nil)
        preview.sharingServicePicker(picker, didChoose: service)
        #expect(ends == [false, true])
        #expect(!preview.sharing)
    }

    private func buttons(in view: NSView) -> [NSButton] {
        view.subviews.flatMap { subview in
            (subview as? NSButton).map { [$0] } ?? buttons(in: subview)
        }
    }
}
