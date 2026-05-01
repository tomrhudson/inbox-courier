import AppKit
import Foundation

@MainActor
final class StatusStore: ObservableObject {
    @Published private(set) var snapshot = AgentSnapshot(
        status: nil,
        isLoaded: false,
        statusFileExists: false,
        generatedAt: Date()
    )
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus = "Unknown"
    @Published var lastCommandMessage: String?

    private let statusURL = URL(
        fileURLWithPath: "\(NSHomeDirectory())/Library/Application Support/InboxCourier/status.json"
    )
    private let logDirectoryURL = URL(
        fileURLWithPath: "\(NSHomeDirectory())/Library/Logs/InboxCourier",
        isDirectory: true
    )
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    deinit {
        timer?.invalidate()
    }

    var menuTitle: String {
        switch snapshot.health {
        case .healthy:
            return "InboxCourier"
        case .pending:
            return "\(snapshot.status?.pendingAfterRun ?? snapshot.status?.pendingBeforeRun ?? 0)"
        case .running:
            return "Syncing"
        case .stale:
            return "Stale"
        case .error:
            return "Error"
        case .unknown:
            return "Unknown"
        }
    }

    var systemImage: String {
        switch snapshot.health {
        case .healthy:
            return "checkmark.circle"
        case .pending:
            return "tray.full"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .stale:
            return "clock.badge.exclamationmark"
        case .error:
            return "exclamationmark.triangle"
        case .unknown:
            return "questionmark.circle"
        }
    }

    var statusURLForDisplay: URL {
        statusURL
    }

    var logDirectoryURLForDisplay: URL {
        logDirectoryURL
    }

    func refresh() {
        let statusFileExists = FileManager.default.fileExists(atPath: statusURL.path)
        let status: AgentStatus?

        if statusFileExists, let data = try? Data(contentsOf: statusURL) {
            status = try? decoder.decode(AgentStatus.self, from: data)
        } else {
            status = nil
        }

        snapshot = AgentSnapshot(
            status: status,
            isLoaded: AgentController.isLoaded(),
            statusFileExists: statusFileExists,
            generatedAt: Date()
        )
        refreshLoginItemStatus()
    }

    func runNow() {
        let result = AgentController.runNow()
        lastCommandMessage = message(for: result, success: "Run requested")
        refresh()
    }

    func reloadAgent() {
        let result = AgentController.reload()
        lastCommandMessage = message(for: result, success: "Agent reloaded")
        refresh()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        let result = LoginItemController.setEnabled(enabled)
        lastCommandMessage = message(for: result, success: result.output)
        refreshLoginItemStatus()
    }

    func openReminders() {
        openApplication(named: "Reminders", bundleIdentifier: "com.apple.reminders")
    }

    func openThings() {
        if !openApplication(named: "Things3", bundleIdentifier: "com.culturedcode.ThingsMac") {
            _ = openApplication(named: "Things", bundleIdentifier: nil)
        }
    }

    func openLogs() {
        NSWorkspace.shared.open(logDirectoryURL)
    }

    func openStatusFile() {
        NSWorkspace.shared.open(statusURL)
    }

    private func message(for result: CommandResult, success: String) -> String {
        if result.exitCode == 0 {
            return success
        }

        let trimmed = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Command failed: \(result.exitCode)" : trimmed
    }

    private func refreshLoginItemStatus() {
        launchAtLoginEnabled = LoginItemController.isEnabled
        launchAtLoginStatus = LoginItemController.statusDescription
    }

    @discardableResult
    private func openApplication(named name: String, bundleIdentifier: String?) -> Bool {
        if let bundleIdentifier,
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            NSWorkspace.shared.open(bundleURL)
            return true
        }

        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        NSWorkspace.shared.open(url)
        return true
    }
}
