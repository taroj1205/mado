import AppKit

extension LauncherView {
    public var scoped: Bool { rootQuery != nil }

    var onEmptyRootQuery: Bool {
        !scoped && field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func enter(placeholder: String) {
        rootQuery = rootQuery ?? field.stringValue
        showScope(placeholder: placeholder)
        replaceQuery(with: "")
    }

    @objc
    public func leave() {
        guard let query = rootQuery else { return }
        rootQuery = nil
        showScope(placeholder: nil)
        replaceQuery(with: query)
    }

    private func showScope(placeholder: String?) {
        let inside = placeholder != nil
        icon.isHidden = inside
        back.isHidden = !inside
        let leading: NSView = inside ? back : icon
        fieldLeading.isActive = false
        fieldLeading = field.leadingAnchor.constraint(
            equalTo: leading.trailingAnchor, constant: Self.searchIconGap)
        fieldLeading.isActive = true
        field.placeholderString = placeholder ?? Self.searchPlaceholder
    }
}
