import AppKit
import QuickLookUI

@MainActor
final class FilePreview {
    static let width: CGFloat = 400
    static let height: CGFloat = 540
    static let gap: CGFloat = 32
    static let edge: CGFloat = 16
    static let minimumWidth: CGFloat = 240
    private static let radius: CGFloat = 24
    private static let headerHeight: CGFloat = 44
    private static let inset: CGFloat = 16
    private static let titleSize: CGFloat = 13
    private static let half: CGFloat = 0.5

    let panel = GlassPanel(
        kind: .hud, contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        shape: .rounded(radius))
    let title = NSTextField(labelWithString: "")
    let view = QLPreviewView(frame: .zero, style: .normal)

    var isVisible: Bool { panel.isVisible }

    init() {
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        let content = NSView()
        for subview in [title, view].compactMap(\.self) {
            subview.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
            title.trailingAnchor.constraint(
                lessThanOrEqualTo: content.trailingAnchor, constant: -Self.inset),
            title.centerYAnchor.constraint(
                equalTo: content.topAnchor, constant: Self.headerHeight * Self.half),
        ])
        if let view {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: content.topAnchor, constant: Self.headerHeight),
                view.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: Self.inset),
                view.trailingAnchor.constraint(
                    equalTo: content.trailingAnchor, constant: -Self.inset),
                view.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Self.inset),
            ])
        }
        panel.glass.contentView = content
    }

    static func frame(beside anchor: CGRect, in visible: CGRect) -> CGRect {
        let right = visible.maxX - anchor.maxX - gap - edge
        let left = anchor.minX - visible.minX - gap - edge
        let size = CGSize(
            width: min(width, max(right, left, minimumWidth)), height: min(height, visible.height))
        let originX =
            right >= left
            ? min(anchor.maxX + gap, visible.maxX - size.width)
            : max(anchor.minX - gap - size.width, visible.minX)
        let originY = min(
            max(anchor.midY - size.height * half, visible.minY), visible.maxY - size.height)
        return CGRect(origin: CGPoint(x: originX, y: originY), size: size)
    }

    func show(_ file: URL, beside anchor: CGRect, in visible: CGRect) {
        title.stringValue = file.lastPathComponent
        view?.previewItem = file as Any as? any QLPreviewItem
        panel.setFrame(Self.frame(beside: anchor, in: visible), display: true)
        panel.orderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
        view?.previewItem = nil
    }
}
