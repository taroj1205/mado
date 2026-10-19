import AppCore

public struct TapAssignments: Equatable, Sendable {
    public private(set) var inputSources: InputSourceSettings
    public private(set) var bindings: ModifierBindings

    public var entries: [ModifierBindings.Entry] {
        let sourceTaps = inputSources.keys.compactMap { key -> ModifierBindings.Entry? in
            guard case .modifierTap(let modifier) = key.hotKey else { return nil }
            return ModifierBindings.Entry(
                tap: ModifierTap.Tap(modifier), action: .inputSource(target: key.target))
        }
        return sourceTaps + bindings.entries
    }

    public init(inputSources: InputSourceSettings, bindings: ModifierBindings) {
        self.inputSources = inputSources
        self.bindings = bindings
    }

    private static func hotKey(of tap: ModifierTap.Tap) -> HotKey? {
        guard tap.count == 1, tap.keys.count == 1, let modifier = tap.keys.first?.modifierKey
        else { return nil }
        return .modifierTap(modifier)
    }

    public func action(for tap: ModifierTap.Tap) -> ModifierAction? {
        entries.first { $0.tap == tap }?.action
    }

    public mutating func bind(_ action: ModifierAction?, to tap: ModifierTap.Tap) {
        let source = Self.hotKey(of: tap)
        if let source, let owner = inputSources.keys.first(where: { $0.hotKey == source }) {
            inputSources.bind(nil, to: owner.target)
        }
        bindings.bind(action, to: tap)
        guard let source, case .inputSource(let target)? = action,
            inputSources.hotKey(for: target) == nil
        else { return }
        bindings.bind(nil, to: tap)
        inputSources.bind(source, to: target)
    }
}
