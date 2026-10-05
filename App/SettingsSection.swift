import AppKit

struct SettingsSection {
    struct Row {
        let label: String
        let control: NSView
        let icon: NSView?
        let example: String?
        let detail: (() -> String)?
        var key: String

        init(_ label: String, _ control: NSView) {
            self.init(label, control, icon: nil, example: nil, detail: nil)
        }

        init(_ label: String, _ control: NSView, icon: NSView?) {
            self.init(label, control, icon: icon, example: nil, detail: nil)
        }

        init(_ label: String, _ control: NSView, example: String?, detail: (() -> String)?) {
            self.init(label, control, icon: nil, example: example, detail: detail)
        }

        init(_ label: String, _ control: NSView, icon: NSView?, detail: (() -> String)?) {
            self.init(label, control, icon: icon, example: nil, detail: detail)
        }

        private init(
            _ label: String, _ control: NSView, icon: NSView?, example: String?,
            detail: (() -> String)?
        ) {
            self.label = label
            key = label
            self.control = control
            self.icon = icon
            self.example = example
            self.detail = detail
        }
    }

    let title: String?
    let note: String?
    var rows: [Row]
    let footer: NSAttributedString?
    let accessory: NSView?
    let headerAccessory: NSView?
    let content: NSView?
    private(set) var columns = 1

    var columnRows: [[Row]] {
        let height = max(1, (rows.count + columns - 1) / columns)
        return stride(from: 0, to: rows.count, by: height).map { start in
            Array(rows[start..<min(start + height, rows.count)])
        }
    }

    init(_ title: String?, _ rows: [Row]) {
        self.init(title, note: nil, rows, footer: nil, accessory: nil, content: nil)
    }

    init(_ title: String?, columns: Int, _ rows: [Row]) {
        self.init(title, note: nil, rows, footer: nil, accessory: nil, content: nil)
        self.columns = columns
    }

    init(_ title: String?, note: String?, _ rows: [Row]) {
        self.init(title, note: note, rows, footer: nil, accessory: nil, content: nil)
    }

    init(_ title: String?, _ rows: [Row], footer: NSAttributedString?, accessory: NSView?) {
        self.init(title, note: nil, rows, footer: footer, accessory: accessory, content: nil)
    }

    init(_ title: String, headerAccessory: NSView, _ rows: [Row]) {
        self.init(
            title, note: nil, rows, footer: nil, accessory: nil, content: nil,
            headerAccessory: headerAccessory)
    }

    init(content: NSView) {
        self.init(nil, note: nil, [], footer: nil, accessory: nil, content: content)
    }

    private init(
        _ title: String?, note: String?, _ rows: [Row], footer: NSAttributedString?,
        accessory: NSView?, content: NSView?, headerAccessory: NSView? = nil
    ) {
        self.title = title
        self.note = note
        self.rows = rows
        self.footer = footer
        self.accessory = accessory
        self.headerAccessory = headerAccessory
        self.content = content
    }
}
