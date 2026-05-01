import Foundation

struct CommandResult {
    let exitCode: Int32
    let output: String
}

enum AgentController {
    static let label = "com.tomrhudson.inboxcourier.agent"
    private static let scriptName = "reminders_to_things.applescript"
    private static let runnerName = "inbox_courier_run.sh"
    private static let plistName = "com.tomrhudson.inboxcourier.agent.plist"
    private static let legacyLabel = "com.siri-to-things.agent"

    static func isLoaded() -> Bool {
        run("/bin/launchctl", ["list", label]).exitCode == 0
    }

    static func isInstalled() -> Bool {
        FileManager.default.fileExists(atPath: installedPlistPath)
            && FileManager.default.fileExists(atPath: installedScriptPath)
            && FileManager.default.fileExists(atPath: installedRunnerPath)
    }

    static func runNow() -> CommandResult {
        guard isInstalled() else {
            return CommandResult(exitCode: 1, output: "Agent is not installed")
        }

        return run("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(label)"])
    }

    static func reload() -> CommandResult {
        guard isInstalled() else {
            return installOrRepair()
        }

        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", installedPlistPath])
        return bootstrapInstalledAgent()
    }

    static func installOrRepair() -> CommandResult {
        do {
            try installResources()
            _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", installedPlistPath])
            _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", legacyPlistPath])
            return bootstrapInstalledAgent()
        } catch {
            return CommandResult(exitCode: 1, output: error.localizedDescription)
        }
    }

    @discardableResult
    static func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return CommandResult(exitCode: process.terminationStatus, output: output)
        } catch {
            return CommandResult(exitCode: 1, output: error.localizedDescription)
        }
    }

    private static var scriptsDirectory: String {
        "\(NSHomeDirectory())/Scripts"
    }

    private static var launchAgentsDirectory: String {
        "\(NSHomeDirectory())/Library/LaunchAgents"
    }

    private static var logDirectory: String {
        "\(NSHomeDirectory())/Library/Logs/InboxCourier"
    }

    private static var installedScriptPath: String {
        "\(scriptsDirectory)/\(scriptName)"
    }

    private static var installedRunnerPath: String {
        "\(scriptsDirectory)/\(runnerName)"
    }

    private static var installedPlistPath: String {
        "\(launchAgentsDirectory)/\(plistName)"
    }

    private static var legacyPlistPath: String {
        "\(launchAgentsDirectory)/\(legacyLabel).plist"
    }

    private static func installResources() throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: scriptsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: launchAgentsDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(atPath: logDirectory, withIntermediateDirectories: true)

        try copyResource(named: scriptName, to: installedScriptPath)
        try copyResource(named: runnerName, to: installedRunnerPath)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: installedRunnerPath)

        let plistTemplate = try resourceString(named: plistName)
        let plist = plistTemplate
            .replacingOccurrences(of: "RUNNER_PATH_PLACEHOLDER", with: installedRunnerPath)
            .replacingOccurrences(of: "SCRIPT_PATH_PLACEHOLDER", with: installedScriptPath)
            .replacingOccurrences(of: "STDOUT_PATH_PLACEHOLDER", with: "\(logDirectory)/launchd.out.log")
            .replacingOccurrences(of: "STDERR_PATH_PLACEHOLDER", with: "\(logDirectory)/launchd.err.log")

        try plist.write(toFile: installedPlistPath, atomically: true, encoding: .utf8)

        let legacyRunnerPath = "\(scriptsDirectory)/siri_to_things_run.sh"
        if fileManager.fileExists(atPath: legacyPlistPath) {
            try? fileManager.removeItem(atPath: legacyPlistPath)
        }
        if fileManager.fileExists(atPath: legacyRunnerPath) {
            try? fileManager.removeItem(atPath: legacyRunnerPath)
        }
    }

    private static func bootstrapInstalledAgent() -> CommandResult {
        let result = run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", installedPlistPath])
        if result.exitCode == 0 {
            return CommandResult(exitCode: 0, output: "Agent installed")
        }

        return result
    }

    private static func copyResource(named name: String, to destination: String) throws {
        guard let source = resourceURL(named: name) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination) {
            try fileManager.removeItem(atPath: destination)
        }
        try fileManager.copyItem(at: source, to: URL(fileURLWithPath: destination))
    }

    private static func resourceString(named name: String) throws -> String {
        guard let source = resourceURL(named: name) else {
            throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: name])
        }

        return try String(contentsOf: source, encoding: .utf8)
    }

    private static func resourceURL(named name: String) -> URL? {
        if let bundledURL = Bundle.main.url(forResource: name, withExtension: nil) {
            return bundledURL
        }

        let repoURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: repoURL.path) {
            return repoURL
        }

        return nil
    }
}
