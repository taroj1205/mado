import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if !enabled {
            try service.unregister()
        } else if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        } else {
            try service.register()
        }
    }
}
