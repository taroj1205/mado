import AppKit

extension LauncherView {
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
        NSLayoutConstraint.deactivate([inside ? fieldAfterIcon : fieldAfterBack])
        NSLayoutConstraint.activate([inside ? fieldAfterBack : fieldAfterIcon])
        field.placeholderString = placeholder ?? Self.searchPlaceholder
    }
}
