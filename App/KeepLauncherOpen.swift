#if DEBUG
    import Foundation

    enum KeepLauncherOpen {
        private static let key = "MadoKeepLauncherOpen"

        static var isEnabled: Bool {
            UserDefaults.standard.bool(forKey: key)
        }

        static func setEnabled(_ enabled: Bool) {
            UserDefaults.standard.set(enabled, forKey: key)
        }
    }
#endif
