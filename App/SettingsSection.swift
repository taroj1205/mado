import AppKit

struct SettingsSection {
    struct Row {
        let label: String
        let control: NSControl
        let example: String?
        let detail: (() -> String)?

        init(_ label: String, _ control: NSControl) {
            self.init(label, control, example: nil, detail: nil)
        }

        init(
            _ label: String, _ control: NSControl, example: String?, detail: (() -> String)?
        ) {
            self.label = label
            self.control = control
            self.example = example
            self.detail = detail
        }
    }

    let title: String?
    let note: String?
    let rows: [Row]

    init(_ title: String?, _ rows: [Row]) {
        self.init(title, note: nil, rows)
    }

    init(_ title: String?, note: String?, _ rows: [Row]) {
        self.title = title
        self.note = note
        self.rows = rows
    }
}
