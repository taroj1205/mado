import AppCore
import AppKit
import SearchKit

final class SettingsPageController: NSViewController {
    private static let titleHeight: CGFloat = 52
    private static let titleCenter: CGFloat = 26
    private static let titleSize: CGFloat = 15
    private static let headerSize: CGFloat = 12
    private static let headerInset: CGFloat = 4
    private static let captionSize: CGFloat = 11
    private static let rowHeight: CGFloat = 40
    private static let rowInset: CGFloat = 4
    private static let iconMargin: CGFloat = 18
    private static let iconGap: CGFloat = 10
    private static let footerSize: CGFloat = 12
    private static let rowPadding: CGFloat = 12
    private static let cornerRadius: CGFloat = 10
    private static let sectionSpacing: CGFloat = 14
    private static let headerSpacing: CGFloat = 6
    private static let leading: CGFloat = 20
    private static let trailing: CGFloat = 24
    private static let bottom: CGFloat = 16

    private let page: SettingsPage
    private let context: SettingsPage.Context
    private let stack = NSStackView()
    private var tab: Int
    private var switches: [SettingsSwitch] = []
    private var popUps: [SettingsPopUp] = []
    private var details: [(label: NSTextField, text: () -> String)] = []

    init(page: SettingsPage, context: SettingsPage.Context) {
        self.page = page
        self.context = context
        tab = page.tabs.firstIndex { $0.sections != nil } ?? 0
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func loadView() {
        let heading = NSTextField(labelWithString: page.title)
        heading.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        heading.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.sectionSpacing
        let scroll = Self.scrolling(
            stack,
            insets: NSEdgeInsets(
                top: 0, left: Self.leading, bottom: Self.bottom, right: Self.trailing))
        let view = NSView()
        view.addSubview(heading)
        view.addSubview(scroll)
        NSLayoutConstraint.activate([
            heading.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: Self.leading),
            heading.centerYAnchor.constraint(equalTo: view.topAnchor, constant: Self.titleCenter),
            scroll.topAnchor.constraint(equalTo: view.topAnchor, constant: Self.titleHeight),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.view = view
        reload()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    func refresh() {
        for toggle in switches {
            toggle.refresh()
        }
        for popUp in popUps {
            popUp.refresh()
        }
        for detail in details {
            detail.label.stringValue = detail.text()
        }
    }

    func reload() {
        var sections = page.tabs[tab].sections?(context) ?? []
        if let module = page.module {
            sections.insert(moduleSection(module), at: 0)
        }
        let controls = sections.flatMap(\.rows).map(\.control)
        switches = controls.compactMap { $0 as? SettingsSwitch }
        popUps = controls.compactMap { $0 as? SettingsPopUp }
        details = []
        for view in stack.arrangedSubviews {
            view.removeFromSuperview()
        }
        for section in sections.map(sectionView) {
            stack.addArrangedSubview(section)
            section.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        if page.tabs.count > 1 {
            stack.insertArrangedSubview(tabPicker(), at: page.module == nil ? 0 : 1)
        }
    }

    private func moduleSection(_ module: ModuleDescriptor) -> SettingsSection {
        let modules = context.modules
        let toggle = SettingsSwitch(
            read: { modules?.isEnabled(module.id) ?? false },
            write: { try modules?.setEnabled(module.id, $0) })
        toggle.isEnabled = modules != nil
        return SettingsSection(nil, [.init(module.name, toggle)])
    }

    private func tabPicker() -> NSSegmentedControl {
        let picker = NSSegmentedControl(
            labels: page.tabs.map(\.title), trackingMode: .selectOne, target: self,
            action: #selector(pickTab))
        for (index, entry) in page.tabs.enumerated() {
            picker.setEnabled(entry.sections != nil, forSegment: index)
        }
        picker.selectedSegment = tab
        return picker
    }

    @objc
    private func pickTab(_ picker: NSSegmentedControl) {
        tab = picker.selectedSegment
        reload()
    }

    private func sectionView(_ section: SettingsSection) -> NSView {
        var parts: [NSView] = []
        if let title = section.title {
            parts.append(header(title, note: section.note, accessory: section.headerAccessory))
        }
        if !section.rows.isEmpty {
            parts.append(Self.columns(section.columnRows.map(box)))
        }
        if let content = section.content {
            parts.append(content)
        }
        if let footer = section.footer {
            let label = NSTextField(wrappingLabelWithString: "")
            label.font = .systemFont(ofSize: Self.footerSize)
            label.textColor = .secondaryLabelColor
            label.attributedStringValue = footer
            let inset = NSStackView(views: [label])
            inset.edgeInsets = NSEdgeInsets(top: 0, left: Self.headerInset, bottom: 0, right: 0)
            parts.append(inset)
        }
        let group = NSStackView(views: parts)
        group.orientation = .vertical
        group.alignment = .leading
        group.spacing = Self.headerSpacing
        for part in parts {
            part.widthAnchor.constraint(equalTo: group.widthAnchor).isActive = true
        }
        if let accessory = section.accessory {
            if let last = parts.last {
                group.setCustomSpacing(Self.sectionSpacing, after: last)
            }
            group.addArrangedSubview(accessory)
        }
        return group
    }

    private func box(_ sectionRows: [SettingsSection.Row]) -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.spacing = 0
        rows.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in sectionRows.enumerated() {
            if index > 0 {
                rows.addArrangedSubview(separator())
            }
            rows.addArrangedSubview(rowView(row))
        }
        for row in rows.arrangedSubviews {
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
        }
        let box = NSBox()
        box.boxType = .custom
        box.titlePosition = .noTitle
        box.cornerRadius = Self.cornerRadius
        box.fillColor = .quaternarySystemFill
        box.borderColor = .separatorColor
        box.addSubview(rows)
        NSLayoutConstraint.activate([
            rows.topAnchor.constraint(equalTo: box.topAnchor),
            rows.bottomAnchor.constraint(equalTo: box.bottomAnchor),
            rows.leadingAnchor.constraint(equalTo: box.leadingAnchor),
            rows.trailingAnchor.constraint(equalTo: box.trailingAnchor),
        ])
        return box
    }

    private func header(_ title: String, note: String?, accessory: NSView?) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: Self.headerSize, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let header = NSStackView(views: [label])
        header.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.headerInset, bottom: 0, right: Self.headerInset)
        if let note {
            let noteLabel = NSTextField(labelWithString: note)
            noteLabel.font = .systemFont(ofSize: Self.headerSize)
            noteLabel.textColor = .secondaryLabelColor
            header.addArrangedSubview(NSView())
            header.addArrangedSubview(noteLabel)
        }
        if let accessory {
            header.addArrangedSubview(NSView())
            header.addArrangedSubview(accessory)
        }
        return header
    }

    private func rowView(_ row: SettingsSection.Row) -> NSView {
        row.control.setAccessibilityLabel(row.label)
        let label = NSTextField(labelWithString: row.label)
        var title: NSView = label
        if let detail = row.detail {
            let detailLabel = NSTextField(labelWithString: detail())
            detailLabel.font = .systemFont(ofSize: Self.captionSize)
            detailLabel.textColor = .secondaryLabelColor
            details.append((detailLabel, detail))
            let lines = NSStackView(views: [label, detailLabel])
            lines.orientation = .vertical
            lines.alignment = .leading
            lines.spacing = 0
            title = lines
        }
        title.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let view = NSStackView(views: [title])
        if let example = row.example {
            let exampleLabel = NSTextField(labelWithString: example)
            exampleLabel.font = .monospacedSystemFont(ofSize: Self.captionSize, weight: .regular)
            exampleLabel.textColor = .secondaryLabelColor
            view.addArrangedSubview(exampleLabel)
        }
        view.addArrangedSubview(row.control)
        view.distribution = .fill
        view.edgeInsets = NSEdgeInsets(
            top: Self.rowInset, left: Self.rowPadding, bottom: Self.rowInset,
            right: Self.rowPadding)
        if let icon = row.icon {
            view.insertArrangedSubview(icon, at: 0)
            view.setCustomSpacing(Self.iconGap, after: icon)
        }
        let height = max(Self.rowHeight, (row.icon?.fittingSize.height ?? 0) + Self.iconMargin)
        let fixedHeight = view.heightAnchor.constraint(equalToConstant: height)
        fixedHeight.priority = .defaultHigh - 1
        fixedHeight.isActive = true
        return view
    }

    private func separator() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        let inset = NSStackView(views: [line])
        inset.edgeInsets = NSEdgeInsets(
            top: 0, left: Self.rowPadding, bottom: 0, right: Self.rowPadding)
        return inset
    }
}
