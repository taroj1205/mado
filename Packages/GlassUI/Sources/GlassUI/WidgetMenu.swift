import AppKit

@MainActor
final class WidgetMenu {
    enum Section: Int {
        case open = 0
        case place = 1
        case edit = 2
        case remove = 3
    }

    enum Choice {
        case open
        case move
        case size
        case pin
        case edit
        case add
        case remove

        var symbol: String {
            switch self {
            case .open: "arrow.up.forward.square"
            case .move: "arrow.up.and.down.and.arrow.left.and.right"
            case .size: WidgetRailsView.resizeSymbol
            case .pin: "pin"
            case .edit: LauncherView.editSymbol
            case .add: "plus"
            case .remove: "trash"
            }
        }

        var opensMore: Bool {
            self == .move || self == .size || self == .pin
        }

        var section: Section {
            switch self {
            case .open: .open
            case .move, .size, .pin: .place
            case .edit, .add: .edit
            case .remove: .remove
            }
        }
    }

    struct Entry {
        let choice: Choice
        let title: String
        var detail: String?
        var size: WidgetGrid.Size?
        var checked = false
    }

    static let width: CGFloat = 244
    private static let tick: CGFloat = 16

    let glass = GlassView(shape: .rounded(ActionPanel.radius))
    private let list = ActionList()

    var onChoose: ((Choice) -> Void)?
    var onSize: ((WidgetGrid.Size) -> Void)?
    var rows: [ActionRow] { list.rows }
    var isVisible: Bool { unsafe glass.superview != nil }

    init() {
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.sheen.isHidden = true
        let content = NSView()
        let border = GlassBorder(radius: ActionPanel.radius)
        for view in [list, border] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        glass.contentView = content
        content.translatesAutoresizingMaskIntoConstraints = false
        let inset = ActionPanel.inset
        NSLayoutConstraint.activate(
            Self.edges(of: border, to: content) + Self.edges(of: content, to: glass) + [
                list.topAnchor.constraint(equalTo: content.topAnchor, constant: inset),
                list.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: inset),
                list.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -inset),
                list.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -inset),
            ])
    }

    private static func edges(of view: NSView, to other: NSView) -> [NSLayoutConstraint] {
        [
            view.leadingAnchor.constraint(equalTo: other.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: other.trailingAnchor),
            view.topAnchor.constraint(equalTo: other.topAnchor),
            view.bottomAnchor.constraint(equalTo: other.bottomAnchor),
        ]
    }

    private static func icon(of entry: Entry) -> NSImage? {
        guard entry.size != nil else {
            return NSImage(systemSymbolName: entry.choice.symbol, accessibilityDescription: nil)
        }
        return entry.checked
            ? NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
            : NSImage(size: NSSize(width: tick, height: tick))
    }

    func show(_ entries: [Entry], for name: String) {
        let made = entries.map { entry in
            let row = ActionRow(
                title: entry.title,
                keys: entry.choice == .open ? LauncherView.Action.primaryKeys : [],
                icon: Self.icon(of: entry), isDestructive: entry.choice == .remove,
                detail: entry.detail, opens: entry.size == nil && entry.choice.opensMore)
            if entry.size != nil {
                row.setAccessibilityValue(entry.checked)
            }
            row.onPress = { [weak self] in
                if let size = entry.size {
                    self?.onSize?(size)
                } else {
                    self?.onChoose?(entry.choice)
                }
            }
            return row
        }
        list.show(made, groups: entries.map(\.choice.section.rawValue), label: name)
    }

    func moveSelection(by offset: Int) {
        list.moveSelection(by: offset)
    }

    func press() {
        list.press()
    }

    func contains(_ point: NSPoint) -> Bool {
        isVisible && glass.convert(glass.bounds, to: nil).contains(point)
    }

    func close() {
        glass.removeFromSuperview()
    }
}
