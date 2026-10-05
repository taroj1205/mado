import AppKit
import ObjectiveC
import Testing

struct SilentWindows: SuiteTrait {
    final class ShownAlpha {
        var value: CGFloat

        init(_ value: CGFloat) { self.value = value }
    }

    @MainActor static let shown = NSMapTable<NSWindow, ShownAlpha>.weakToStrongObjects()

    static let installed: Void = {
        let pairs: [(Selector, Selector)] = [
            (#selector(NSWindow.orderFront(_:)), #selector(NSWindow.silentOrderFront(_:))),
            (
                #selector(NSWindow.orderFrontRegardless),
                #selector(NSWindow.silentOrderFrontRegardless)
            ),
            (
                #selector(NSWindow.makeKeyAndOrderFront(_:)),
                #selector(NSWindow.silentMakeKeyAndOrderFront(_:))
            ),
            (
                #selector(NSWindow.order(_:relativeTo:)),
                #selector(NSWindow.silentOrderWindow(_:relativeTo:))
            ),
            (
                #selector(NSWindow.addChildWindow(_:ordered:)),
                #selector(NSWindow.silentAddChildWindow(_:ordered:))
            ),
            (#selector(getter: NSWindow.alphaValue), #selector(NSWindow.silentAlphaValue)),
            (#selector(setter: NSWindow.alphaValue), #selector(NSWindow.silentSetAlphaValue(_:))),
        ]
        for (original, replacement) in pairs {
            guard let first = unsafe class_getInstanceMethod(NSWindow.self, original),
                let second = unsafe class_getInstanceMethod(NSWindow.self, replacement)
            else { continue }
            unsafe method_exchangeImplementations(first, second)
        }
    }()
}

extension Trait where Self == SilentWindows {
    static var silentWindows: Self {
        SilentWindows.installed
        return .init()
    }
}

extension NSWindow {
    func goSilent() {
        guard SilentWindows.shown.object(forKey: self) == nil else { return }
        SilentWindows.shown.setObject(SilentWindows.ShownAlpha(alphaValue), forKey: self)
        silentSetAlphaValue(0)
        animationBehavior = .none
    }

    @objc func silentOrderFront(_ sender: Any?) {
        goSilent()
        silentOrderFront(sender)
    }

    @objc func silentOrderFrontRegardless() {
        goSilent()
        silentOrderFrontRegardless()
    }

    @objc func silentMakeKeyAndOrderFront(_ sender: Any?) {
        goSilent()
        silentMakeKeyAndOrderFront(sender)
    }

    @objc func silentOrderWindow(_ place: NSWindow.OrderingMode, relativeTo other: Int) {
        goSilent()
        silentOrderWindow(place, relativeTo: other)
    }

    @objc func silentAddChildWindow(
        _ child: NSWindow, ordered place: NSWindow.OrderingMode
    ) {
        child.goSilent()
        silentAddChildWindow(child, ordered: place)
    }

    @objc func silentAlphaValue() -> CGFloat {
        guard let shown = SilentWindows.shown.object(forKey: self) else {
            return silentAlphaValue()
        }
        return shown.value
    }

    @objc func silentSetAlphaValue(_ value: CGFloat) {
        if let shown = SilentWindows.shown.object(forKey: self) {
            shown.value = value
        } else {
            silentSetAlphaValue(value)
        }
    }
}
