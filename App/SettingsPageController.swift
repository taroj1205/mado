import AppCore
import AppKit
import SearchKit

final class SettingsPageController: NSViewController {
    private static let titleHeight: CGFloat = 52
    private static let titleCenter: CGFloat = 26
    private static let titleSize: CGFloat = 15
    private static let headerSize: CGFloat = 12
    static let headerInset: CGFloat = 4
    private static let sectionSpacing: CGFloat = 14
    private static let headerSpacing: CGFloat = 6
    private static let leading: CGFloat = 20
    private static let trailing: CGFloat = 24
    private static let bottom: CGFloat = 16

    private let page: SettingsPage
    private let context: SettingsPage.Context
    let stack = NSStackView()
    private var tab: Int
    private var switches: [SettingsSwitch] = []
    private var popUps: [SettingsPopUp] = []
    var details: [(label: NSTextField, text: () -> String)] = []
    private var moduleToggle: NSView?
    let spotlight = SettingsSpotlight()
    private(set) var shown: SettingsFinder.Shown?
    var onPickTab: (() -> Void)?

    var tabTitle: String? {
        page.tabs.count > 1 ? page.tabs[tab].title : nil
    }

    private var moduleRowID: String? {
        page.module.map { SettingsFinder.moduleID(page: page.title, name: $0.name) }
    }

    private var isModuleOff: Bool {
        guard let module = page.module, let modules = context.modules else { return false }
        return !modules.isEnabled(module.id)
    }

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

    func show(tab title: String?) {
        guard let title, let index = page.tabs.firstIndex(where: { $0.title == title }),
            index != tab, page.tabs[index].sections != nil
        else { return }
        tab = index
        reload()
    }

    func reload() {
        let built = page.tabs[tab].sections?(context) ?? []
        shown = .init(page: page.title, tab: page.tabs[tab].title, sections: built)
        var sections = built
        spotlight.reset(moduleRow: moduleRowID, moduleOff: isModuleOff)
        if let module = page.module {
            let toggle = moduleRow(module)
            moduleToggle = toggle.control
            if sections.first?.title == module.name {
                sections[0].rows.insert(toggle, at: 0)
            } else {
                sections.insert(SettingsSection(nil, [toggle]), at: 0)
            }
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
        spotlight.refresh()
    }

    private func moduleRow(_ module: ModuleDescriptor) -> SettingsSection.Row {
        let modules = context.modules
        let toggle = SettingsSwitch(
            read: { modules?.isEnabled(module.id) ?? false },
            write: { [weak self] isOn in
                try modules?.setEnabled(module.id, isOn)
                self?.spotlight.moduleOff = !isOn
            })
        toggle.isEnabled = modules != nil
        return .init(module.name, toggle)
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
        onPickTab?()
        reload()
    }

    private func sectionView(_ section: SettingsSection) -> NSView {
        var parts: [NSView] = []
        if let title = section.title {
            let view = header(title, note: section.note, accessory: section.headerAccessory)
            spotlight.add(header: view, rows: section.rows.map { rowID($0, in: section) })
            parts.append(view)
        }
        if !section.rows.isEmpty {
            parts.append(Self.columns(section.columnRows.map { box($0, in: section) }))
        }
        if let content = section.content {
            parts.append(content)
        }
        if let footer = section.footer {
            parts.append(Self.footer(footer))
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

    private func rowID(_ row: SettingsSection.Row, in section: SettingsSection) -> String {
        if row.control === moduleToggle, let moduleRowID {
            return moduleRowID
        }
        return SettingsFinder.id(
            page: page.title, tab: tabTitle, section: section.title, key: row.key)
    }

    private func box(_ sectionRows: [SettingsSection.Row], in section: SettingsSection) -> NSView {
        Self.box(
            sectionRows.map { row in
                let (view, label) = rowView(row)
                spotlight.add(
                    row: view, label: label, control: row.control, id: rowID(row, in: section))
                return view
            })
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
}
