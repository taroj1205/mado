import AppKit
import QuickLookUI

@MainActor
final class FilePreview: NSObject, NSSharingServicePickerDelegate {
    static let width: CGFloat = 400
    static let height: CGFloat = 540
    static let gap: CGFloat = 32
    static let edge: CGFloat = 16
    static let minimumWidth: CGFloat = 240
    private static let radius: CGFloat = 24
    private static let headerHeight: CGFloat = 44
    private static let titleLeading: CGFloat = 16
    private static let buttonTrailing: CGFloat = 12
    private static let buttonGap: CGFloat = 6
    private static let buttonHeight: CGFloat = 26
    private static let buttonInset: CGFloat = 12
    private static let sheetInset: CGFloat = 16
    private static let sheetRadius: CGFloat = 10
    private static let sheetGray: CGFloat = 0.961
    private static let sheetBlue: CGFloat = 0.969
    private static let detailsTop: CGFloat = 12
    private static let detailsSide: CGFloat = 18
    private static let detailsBottom: CGFloat = 16
    private static let detailsGap: CGFloat = 4
    private static let titleSize: CGFloat = 13
    private static let detailSize: CGFloat = 12
    private static let half: CGFloat = 0.5
    private static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    let panel = GlassPanel(
        kind: .hud, contentRect: NSRect(x: 0, y: 0, width: width, height: height),
        shape: .rounded(radius))
    let title = NSTextField(labelWithString: "")
    let view = QLPreviewView(frame: .zero, style: .compact)
    let kind = FilePreview.detail(color: .labelColor)
    let size = FilePreview.detail(color: .labelColor)
    let modified = FilePreview.detail(color: .labelColor)
    let sizeRow: NSView
    var onOpen: (() -> Void)?
    var onShareEnd: ((Bool) -> Void)?
    private(set) var sharing = false
    private var file: URL?

    var isVisible: Bool { panel.isVisible }

    override init() {
        sizeRow = Self.row("Size", size)
        super.init()
        panel.ignoresMouseEvents = false
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.lineBreakMode = .byTruncatingMiddle
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let header = NSStackView(views: [
            title, pill("Open", action: #selector(open)), pill("Share", action: #selector(share)),
        ])
        header.spacing = Self.buttonGap
        header.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.titleLeading, bottom: 0, right: Self.buttonTrailing)
        let sheet = NSView()
        sheet.wantsLayer = true
        sheet.layer?.cornerRadius = Self.sheetRadius
        sheet.layer?.masksToBounds = true
        sheet.layer?.backgroundColor = CGColor(
            srgbRed: Self.sheetGray, green: Self.sheetGray, blue: Self.sheetBlue, alpha: 1)
        if let view {
            view.autoresizingMask = [.width, .height]
            sheet.addSubview(view)
        }
        let rows = [Self.row("Kind", kind), sizeRow, Self.row("Modified", modified)]
        let details = NSStackView(views: rows)
        details.orientation = .vertical
        details.spacing = Self.detailsGap
        for row in rows {
            row.widthAnchor.constraint(equalTo: details.widthAnchor).isActive = true
        }
        layout(header, sheet, details)
    }

    static func frame(beside anchor: CGRect, in visible: CGRect) -> CGRect {
        let right = visible.maxX - anchor.maxX - gap - edge
        let left = anchor.minX - visible.minX - gap - edge
        let frameSize = CGSize(
            width: min(width, max(right, left, minimumWidth)), height: min(height, visible.height))
        let originX =
            right >= left
            ? min(anchor.maxX + gap, visible.maxX - frameSize.width)
            : max(anchor.minX - gap - frameSize.width, visible.minX)
        let originY = min(
            max(anchor.midY - frameSize.height * half, visible.minY),
            visible.maxY - frameSize.height)
        return CGRect(origin: CGPoint(x: originX, y: originY), size: frameSize)
    }

    static func modifiedText(_ date: Date) -> String {
        day.string(from: date) + ", " + date.formatted(date: .omitted, time: .shortened)
    }

    private static func detail(color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: detailSize)
        label.textColor = color
        label.lineBreakMode = .byTruncatingMiddle
        return label
    }

    private static func row(_ name: String, _ value: NSTextField) -> NSView {
        let label = detail(color: .secondaryLabelColor)
        label.stringValue = name
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        value.alignment = .right
        value.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, value])
        row.distribution = .fill
        return row
    }

    func show(_ file: URL, beside anchor: CGRect, in visible: CGRect) {
        self.file = file
        title.stringValue = file.lastPathComponent
        view?.previewItem = file as Any as? any QLPreviewItem
        var url = file
        url.removeAllCachedResourceValues()
        let values = try? url.resourceValues(forKeys: [
            .localizedTypeDescriptionKey, .fileSizeKey, .contentModificationDateKey,
        ])
        kind.stringValue = values?.localizedTypeDescription ?? ""
        let bytes = values?.fileSize.map(Int64.init)
        size.stringValue =
            bytes.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? ""
        sizeRow.isHidden = bytes == nil
        modified.stringValue = values?.contentModificationDate.map(Self.modifiedText) ?? ""
        panel.setFrame(Self.frame(beside: anchor, in: visible), display: true)
        panel.orderFront(nil)
    }

    func close() {
        panel.orderOut(nil)
        view?.previewItem = nil
        file = nil
    }

    @objc
    func open() {
        onOpen?()
    }

    @objc
    func share(_ sender: NSButton) {
        guard let file else { return }
        let picker = NSSharingServicePicker(items: [file])
        picker.delegate = self
        sharing = true
        picker.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    func sharingServicePicker(
        _: NSSharingServicePicker, didChoose service: NSSharingService?
    ) {
        sharing = false
        onShareEnd?(service != nil)
    }

    private func pill(_ name: String, action: Selector) -> NSView {
        let button = NSButton(title: name, target: self, action: action)
        button.isBordered = false
        button.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        button.contentTintColor = .labelColor
        let box = NSBox()
        box.boxType = .custom
        box.borderWidth = 0
        box.cornerRadius = Self.buttonHeight * Self.half
        box.fillColor = FloatingCapsule.keycapFill
        box.contentViewMargins = .zero
        button.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(button)
        NSLayoutConstraint.activate([
            box.heightAnchor.constraint(equalToConstant: Self.buttonHeight),
            box.widthAnchor.constraint(
                equalToConstant: button.intrinsicContentSize.width + Self.buttonInset
                    + Self.buttonInset),
            button.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: box.trailingAnchor),
            button.topAnchor.constraint(equalTo: box.topAnchor),
            button.bottomAnchor.constraint(equalTo: box.bottomAnchor),
        ])
        return box
    }

    private func layout(_ header: NSView, _ sheet: NSView, _ details: NSView) {
        let content = NSView()
        for subview in [header, sheet, details] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(subview)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            sheet.topAnchor.constraint(equalTo: header.bottomAnchor),
            sheet.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: Self.sheetInset),
            sheet.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -Self.sheetInset),
            details.topAnchor.constraint(equalTo: sheet.bottomAnchor, constant: Self.detailsTop),
            details.leadingAnchor.constraint(
                equalTo: content.leadingAnchor, constant: Self.detailsSide),
            details.trailingAnchor.constraint(
                equalTo: content.trailingAnchor, constant: -Self.detailsSide),
            details.bottomAnchor.constraint(
                equalTo: content.bottomAnchor, constant: -Self.detailsBottom),
        ])
        panel.glass.contentView = content
    }
}
