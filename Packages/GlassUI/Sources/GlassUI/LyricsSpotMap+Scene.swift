import AppKit

extension LyricsSpotMap {
    private static let night = 0.62
    private static let dusk = 0.35
    private static let dawn = 0.12
    private static let glowSize: CGFloat = 230
    private static let glowAlpha = 0.5
    private static let barAlpha = 0.34
    private static let strongText = 0.85
    private static let softText = 0.5
    private static let apple: CGFloat = 6
    private static let menuHeight: CGFloat = 4
    private static let appWidth: CGFloat = 24
    private static let menuWidth: CGFloat = 18
    private static let menuCount = 3
    private static let statusWidth: CGFloat = 12
    private static let statusCount = 3
    private static let menuLeft: CGFloat = 9
    private static let menuGap: CGFloat = 8
    private static let windowFill = 0.07
    private static let windowStroke = 0.16
    private static let windowRadius: CGFloat = 7
    private static let titleHeight: CGFloat = 10
    private static let dot: CGFloat = 4
    private static let dotAlpha = 0.75
    private static let dockFill = 0.16
    private static let dockStroke = 0.28
    private static let icon: CGFloat = 15
    private static let iconGap: CGFloat = 5
    private static let iconRadius: CGFloat = 4
    private static let half: CGFloat = 0.5
    private static let apps: [NSColor] = [
        .systemBlue, .systemOrange, .systemGreen, .systemPink, .systemPurple, .systemTeal,
        .systemYellow,
    ]
    private static let lights: [NSColor] = [.systemRed, .systemYellow, .systemGreen]

    func buildScene() {
        let dark = NSAppearance(named: .darkAqua)
        dark?.performAsCurrentDrawingAppearance {
            wallpaper()
            glow(.systemTeal, at: CGPoint(x: Self.edge, y: Self.height))
            glow(.systemPink, at: CGPoint(x: Self.width, y: 0))
            window()
            menuBar()
            dock()
        }
    }

    private func wallpaper() {
        let sky = CAGradientLayer()
        sky.frame = CGRect(origin: .zero, size: CGSize(width: Self.width, height: Self.height))
        sky.colors = [
            NSColor.systemIndigo.blended(withFraction: Self.night, of: .black),
            NSColor.systemPurple.blended(withFraction: Self.dusk, of: .black),
            NSColor.systemPink.blended(withFraction: Self.dawn, of: .black),
        ].compactMap { $0?.cgColor }
        sky.startPoint = .zero
        sky.endPoint = CGPoint(x: 1, y: 1)
        layer?.addSublayer(sky)
    }

    private func glow(_ tint: NSColor, at centre: CGPoint) {
        let spot = CAGradientLayer()
        spot.type = .radial
        spot.frame = CGRect(
            x: centre.x - Self.glowSize * Self.half, y: centre.y - Self.glowSize * Self.half,
            width: Self.glowSize, height: Self.glowSize)
        spot.colors = [tint.withAlphaComponent(Self.glowAlpha).cgColor, NSColor.clear.cgColor]
        spot.startPoint = CGPoint(x: Self.half, y: Self.half)
        spot.endPoint = CGPoint(x: 1, y: 1)
        layer?.addSublayer(spot)
    }

    private func window() {
        let top = Self.islandHeight + Self.barHeight + Self.edge + Self.gap
        let side = Self.edge + Self.cardWidth + Self.gap
        let bottom = (Self.frames[.desktop]?.minY ?? Self.height) - Self.gap
        let body = CALayer()
        body.isGeometryFlipped = true
        body.frame = CGRect(x: side, y: top, width: Self.width - side - side, height: bottom - top)
        body.cornerRadius = Self.windowRadius
        body.cornerCurve = .continuous
        body.backgroundColor = NSColor.white.withAlphaComponent(Self.windowFill).cgColor
        body.borderColor = NSColor.white.withAlphaComponent(Self.windowStroke).cgColor
        body.borderWidth = 1
        for (index, tint) in Self.lights.enumerated() {
            let light = CALayer()
            light.frame = CGRect(
                x: Self.dot + CGFloat(index) * (Self.dot + Self.dot),
                y: (Self.titleHeight - Self.dot) * Self.half, width: Self.dot, height: Self.dot)
            light.cornerRadius = Self.dot * Self.half
            light.backgroundColor = tint.withAlphaComponent(Self.dotAlpha).cgColor
            body.addSublayer(light)
        }
        layer?.addSublayer(body)
    }

    private func menuBar() {
        let bar = CALayer()
        bar.isGeometryFlipped = true
        bar.frame = CGRect(x: 0, y: 0, width: Self.width, height: Self.barHeight)
        bar.backgroundColor = NSColor.black.withAlphaComponent(Self.barAlpha).cgColor
        let middle = (Self.barHeight - Self.menuHeight) * Self.half
        let strong = NSColor.white.withAlphaComponent(Self.strongText)
        let soft = NSColor.white.withAlphaComponent(Self.softText)
        let logo = CGRect(
            x: Self.menuLeft, y: (Self.barHeight - Self.apple) * Self.half, width: Self.apple,
            height: Self.apple)
        bar.addSublayer(chip(logo, strong, round: true))
        var next = logo.maxX + Self.menuGap
        for index in 0...Self.menuCount {
            let width = index == 0 ? Self.appWidth : Self.menuWidth
            let frame = CGRect(x: next, y: middle, width: width, height: Self.menuHeight)
            bar.addSublayer(chip(frame, index == 0 ? strong : soft, round: true))
            next += width + Self.menuGap
        }
        next = Self.statusStart
        for _ in 0..<Self.statusCount {
            let frame = CGRect(x: next, y: middle, width: Self.statusWidth, height: Self.menuHeight)
            bar.addSublayer(chip(frame, soft, round: true))
            next += Self.statusWidth + Self.menuGap
        }
        layer?.addSublayer(bar)
    }

    private func dock() {
        let frame = Self.dockFrame
        let shelf = CALayer()
        shelf.isGeometryFlipped = true
        shelf.frame = frame
        shelf.cornerRadius = Self.iconRadius + Self.iconGap
        shelf.cornerCurve = .continuous
        shelf.backgroundColor = NSColor.white.withAlphaComponent(Self.dockFill).cgColor
        shelf.borderColor = NSColor.white.withAlphaComponent(Self.dockStroke).cgColor
        shelf.borderWidth = 1
        let row = CGFloat(Self.apps.count) * (Self.icon + Self.iconGap) - Self.iconGap
        for (index, tint) in Self.apps.enumerated() {
            let tile = CGRect(
                x: (frame.width - row) * Self.half + CGFloat(index) * (Self.icon + Self.iconGap),
                y: (frame.height - Self.icon) * Self.half, width: Self.icon, height: Self.icon)
            shelf.addSublayer(chip(tile, tint, round: false))
        }
        layer?.addSublayer(shelf)
    }

    private func chip(_ frame: CGRect, _ colour: NSColor, round: Bool) -> CALayer {
        let chip = CALayer()
        chip.frame = frame
        chip.cornerRadius = round ? frame.height * Self.half : Self.iconRadius
        chip.cornerCurve = .continuous
        chip.backgroundColor = colour.cgColor
        return chip
    }
}
