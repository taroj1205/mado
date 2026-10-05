import AppCore
import AppKit

extension WidgetMonth {
    var isAwayFromToday: Bool {
        showsDay ? dayPage.day?.isToday == false : (shown?.shift ?? 0) != 0
    }

    func reveal(day wanted: Bool) {
        guard wanted != showsDay else { return }
        showsDay = wanted
        let entering: NSView = wanted ? dayPage : page
        let leaving: NSView = wanted ? page : dayPage
        let way: CGFloat = wanted ? 1 : -1
        entering.isHidden = false
        guard animates else {
            leaving.isHidden = true
            entering.frame = bounds
            entering.alphaValue = 1
            return
        }
        entering.frame = bounds.offsetBy(dx: Self.travel * way, dy: 0)
        entering.alphaValue = 0
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = Self.slide
                context.timingFunction = CAMediaTimingFunction(
                    controlPoints: Float(Self.slideStart.x), Float(Self.slideStart.y),
                    Float(Self.slideEnd.x), Float(Self.slideEnd.y))
                entering.animator().frame = bounds
                entering.animator().alphaValue = 1
                leaving.animator().frame = bounds.offsetBy(dx: -Self.travel * way, dy: 0)
                leaving.animator().alphaValue = 0
            },
            completionHandler: {
                MainActor.assumeIsolated {
                    guard leaving.alphaValue == 0 else { return }
                    leaving.isHidden = true
                    leaving.frame = self.bounds
                }
            })
    }
}
