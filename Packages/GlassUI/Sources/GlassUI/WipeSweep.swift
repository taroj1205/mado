import AppCore

struct WipeSweep: Equatable {
    static let still = Self(start: 1, remaining: nil, ahead: [])

    let start: Double
    let remaining: Double?
    let ahead: [Lyrics.Step]
}

extension WidgetGrid.Lyric {
    var sweep: WipeSweep {
        WipeSweep(start: progress, remaining: remaining, ahead: ahead)
    }
}

extension WidgetGrid.Verse {
    var sweep: WipeSweep {
        WipeSweep(start: progress, remaining: remaining, ahead: ahead)
    }
}
