import AppCore
import AppKit
import InputKit
import WindowKit

extension ModifierKeysSettings {
    private final class Choice {
        let run: @MainActor () -> Void

        init(_ run: @escaping @MainActor () -> Void) {
            self.run = run
        }
    }

    func choose(
        _ tap: ModifierTap.Tap, current: ModifierAction?, from chip: TapChip
    ) {
        chip.show(targets(for: tap, current: current, from: chip))
    }

    func gestures(
        besides key: ModifierTap.Key, free: [ModifierTap.Tap], from chip: TapChip
    ) -> NSMenu {
        let menu = NSMenu()
        for tap in free where tap.keys.count == 1 {
            menu.addItem(item(Self.title(of: tap, besides: key), run: pick(tap, from: chip)))
        }
        let partners = free.filter { $0.keys.count > 1 }.map { tap in
            item(
                Self.name(of: tap.keys.subtracting([key]).first ?? key), run: pick(tap, from: chip))
        }
        if !partners.isEmpty {
            menu.addItem(submenu("Together with", partners))
        }
        return menu
    }

    private func pick(_ tap: ModifierTap.Tap, from chip: TapChip) -> @MainActor () -> Void {
        { [weak self, weak chip] in
            guard let chip else { return }
            self?.choose(tap, current: nil, from: chip)
        }
    }

    private func targets(
        for tap: ModifierTap.Tap, current: ModifierAction?, from chip: TapChip
    ) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu("Input source", sources(for: tap, current: current)))
        menu.addItem(
            item("App…", isOn: isApp(current)) { [weak self, weak chip] in
                guard let chip else { return }
                AppPicker.pick(from: chip) { self?.bind(.item(id: $0.path), to: tap) }
            })
        menu.addItem(submenu("Command", commands(for: tap, current: current)))
        if current != nil {
            menu.addItem(.separator())
            menu.addItem(item("Remove") { [weak self] in self?.bind(nil, to: tap) })
        }
        return menu
    }

    private func sources(
        for tap: ModifierTap.Tap, current: ModifierAction?
    ) -> [NSMenuItem] {
        let installed = InputSource.enabled.map { InputTarget.source(id: $0.id) }
        let targets: [InputTarget] = [.english, .japanese, .next] + installed
        return targets.map { target in
            item(
                InputSourceKeys.label(of: target), isOn: current == .inputSource(target: target)
            ) { [weak self] in self?.bind(.inputSource(target: target), to: tap) }
        }
    }

    private func commands(
        for tap: ModifierTap.Tap, current: ModifierAction?
    ) -> [NSMenuItem] {
        let all = modules?.commands.all ?? []
        let sorted = all.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !sorted.isEmpty else {
            return [NSMenuItem(title: "No commands", action: nil, keyEquivalent: "")]
        }
        return sorted.map { command in
            item(command.name, isOn: current == .item(id: command.id)) { [weak self] in
                self?.bind(.item(id: command.id), to: tap)
            }
        }
    }

    private func isApp(_ action: ModifierAction?) -> Bool {
        guard case .item(let id)? = action else { return false }
        return AppToggle.app(for: id) != nil
    }

    private func item(
        _ title: String, isOn: Bool = false, run: @escaping @MainActor () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(runChoice), keyEquivalent: "")
        item.target = self
        item.state = isOn ? .on : .off
        item.representedObject = Choice(run)
        return item
    }

    private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let menu = NSMenu(title: title)
        for entry in items {
            menu.addItem(entry)
        }
        parent.submenu = menu
        return parent
    }

    @objc
    private func runChoice(_ item: NSMenuItem) {
        (item.representedObject as? Choice)?.run()
    }
}
