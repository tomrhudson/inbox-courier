import Foundation
import ServiceManagement

enum LoginItemController {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notRegistered:
            return "Off"
        case .requiresApproval:
            return "Needs approval"
        case .notFound:
            return "Unavailable"
        @unknown default:
            return "Unknown"
        }
    }

    static func setEnabled(_ enabled: Bool) -> CommandResult {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
                return CommandResult(exitCode: 0, output: "Launch at login enabled")
            } else {
                if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                }
                return CommandResult(exitCode: 0, output: "Launch at login disabled")
            }
        } catch {
            return CommandResult(exitCode: 1, output: error.localizedDescription)
        }
    }
}
