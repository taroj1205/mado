import AppKit

extension LyricsCard {
    private static let lineHeight: CGFloat = 44
    private static let lineLeading: CGFloat = 10
    private static let lineTrailing: CGFloat = 18
    private static let gap: CGFloat = 10
    private static let inset: CGFloat = 16
    private static let headerTop: CGFloat = 12
    private static let glyphBox: CGFloat = 15
    private static let controlStep: CGFloat = 26
    private static let lyricGap: CGFloat = 14
    private static let lyricHeight: CGFloat = 22
    private static let followingGap: CGFloat = 4
    private static let columnGap: CGFloat = 6
    private static let columnHeight: CGFloat = 190
    private static let half: CGFloat = 0.5

    func reveal() {
        let hasLine = text?.line != nil
        chip.isHidden = look != .line
        line.isHidden = look != .line
        header.forEach { $0.isHidden = look == .line }
        lyric.isHidden = look != .card || !hasLine
        following.isHidden = lyric.isHidden
        column.isHidden = look != .lyrics || !hasLine
    }

    func arrange() {
        let width = bounds.width
        let chipTop = (Self.lineHeight - Self.chipSize) * Self.half
        chip.frame = NSRect(
            x: Self.lineLeading, y: chipTop, width: Self.chipSize, height: Self.chipSize)
        let lineLeft = chip.frame.maxX + Self.gap
        line.frame = band(
            left: lineLeft, width: width - lineLeft - Self.lineTrailing,
            height: line.intrinsicContentSize.height, mid: Self.lineHeight * Self.half)
        cover.frame = NSRect(
            x: Self.inset, y: Self.headerTop, width: Self.coverSize, height: Self.coverSize)
        arrangeHeader(width: width)
        let lyricTop = cover.frame.maxY + Self.lyricGap
        lyric.frame = band(
            left: Self.inset, width: width - Self.inset - Self.inset,
            height: lyric.intrinsicContentSize.height,
            mid: lyricTop + Self.lyricHeight * Self.half)
        following.frame = NSRect(
            x: Self.inset, y: lyricTop + Self.lyricHeight + Self.followingGap,
            width: width - Self.inset - Self.inset,
            height: following.intrinsicContentSize.height)
        column.frame = NSRect(
            x: Self.inset, y: cover.frame.maxY + Self.columnGap,
            width: width - Self.inset - Self.inset, height: Self.columnHeight)
    }

    private func arrangeHeader(width: CGFloat) {
        let middle = cover.frame.midY
        let last = width - Self.inset - Self.glyphBox * Self.half
        for (index, button) in controls.reversed().enumerated() {
            let side = LyricsCardButton.side
            button.frame = band(
                left: last - CGFloat(index) * Self.controlStep - side * Self.half, width: side,
                height: side, mid: middle)
        }
        let left = cover.frame.maxX + Self.gap
        let room = max(
            previous.frame.minX + (LyricsCardButton.side - Self.glyphBox) * Self.half
                - Self.gap - left, 0)
        let heights = (
            title: title.intrinsicContentSize.height, artist: artist.intrinsicContentSize.height
        )
        let top = middle - (heights.title + heights.artist) * Self.half
        title.frame = NSRect(x: left, y: top, width: room, height: heights.title)
        artist.frame = NSRect(x: left, y: title.frame.maxY, width: room, height: heights.artist)
    }

    private func band(left: CGFloat, width: CGFloat, height: CGFloat, mid: CGFloat) -> NSRect {
        NSRect(
            x: left, y: (mid - height * Self.half).rounded(), width: max(width, 0),
            height: height)
    }
}
