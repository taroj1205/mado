import AppCore
import AppKit
import GlassUI
import InputKit
import os

@MainActor
final class MeetingJoinReminder {
    private static let interval: TimeInterval = 10
    private static let margin: CGFloat = 12
    private static let route = "meeting join keys"
    private static let fallbackJoinKey: CGKeyCode = 0x26

    private let logger = Log.logger("MeetingJoinReminder")
    private let hud = MeetingJoinHUD()
    private weak var modules: ModuleManager?
    private var reminder = JoinReminder(you: NSFullUserName())
    private var prompt: JoinPrompt?
    private var fetching: Task<Void, Never>?
    private let upNext = UpNextFeed()

    private static func frame(for size: CGSize) -> CGRect {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return CGRect(
            x: visible.maxX - size.width - margin, y: visible.maxY - size.height - margin,
            width: size.width, height: size.height)
    }

    private static func isJoinKey(_ event: CGEvent) -> Bool {
        let modifiers: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
        guard event.flags.intersection(modifiers) == .maskCommand else { return false }
        let join = KeyboardLayout.commandKeyCode(typing: "j") ?? fallbackJoinKey
        return event.getIntegerValueField(.keyboardEventKeycode) == Int64(join)
    }

    func start(context: ModuleContext, modules: ModuleManager) {
        self.modules = modules
        hud.onJoin = { [weak self] in self?.join() }
        hud.onSnooze = { [weak self] in self?.snooze() }
        hud.onDismiss = { [weak self] in self?.dismiss() }
        context.scheduleTimer("meeting join reminder", interval: Self.interval) { [weak self] in
            self?.refresh()
        }
        upNext.refreshOnChange(in: context) { [weak self] in self?.refresh() }
        context.startKeyFeatures { watchKeys(in: context) }
        refresh()
    }

    func stop() {
        fetching?.cancel()
        fetching = nil
        modules = nil
        reminder = JoinReminder(you: NSFullUserName())
        clear()
    }

    private func refresh() {
        fetching?.cancel()
        guard modules != nil, CalendarAgenda.hasAccess else {
            clear()
            return
        }
        fetching = Task { [weak self] in
            let found = await self?.upNext.found(around: .now) ?? []
            guard !Task.isCancelled else { return }
            self?.show(Agenda(events: found.map(\.event)), at: .now)
        }
    }

    private func show(_ agenda: Agenda, at now: Date) {
        let lead = MeetingHUDSettings.load(from: modules).lead.rawValue
        guard let due = reminder.due(in: agenda, at: now, leadMinutes: lead) else {
            clear()
            return
        }
        guard due != prompt else { return }
        prompt = due
        hud.show(due, keys: CalendarAgenda.joinKeys, placing: Self.frame)
    }

    private func clear() {
        prompt = nil
        hud.hide()
    }

    private func watchKeys(in context: ModuleContext) {
        context.installWhenTrusted(Self.route) { [weak self, weak context] in
            guard let context else { return true }
            do {
                try context.tapEvents(Self.route, matching: [.keyDown]) { _, event in
                    self?.handle(event) ?? false
                }
                return true
            } catch {
                return false
            }
        }
    }

    private func handle(_ event: CGEvent) -> Bool {
        guard prompt != nil, NSApp.keyWindow == nil, Self.isJoinKey(event) else { return false }
        join()
        return true
    }

    private func join() {
        guard let prompt else { return }
        dismiss()
        CalendarAgenda.join(prompt.meeting).run(logging: logger)
    }

    private func snooze() {
        guard let prompt else { return }
        reminder.snooze(prompt.event, at: .now)
        clear()
    }

    private func dismiss() {
        guard let prompt else { return }
        reminder.dismiss(prompt.event)
        clear()
    }
}
