import AppCore
import AppKit
import os

let signposter = Log.signposter(OSLog.Category.pointsOfInterest.rawValue)
let launch = signposter.beginInterval("launch")
let app = NSApplication.shared
let delegate = AppDelegate(signposter: signposter, launch: launch)
app.delegate = delegate
app.run()
