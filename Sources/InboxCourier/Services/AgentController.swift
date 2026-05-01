import Foundation

struct CommandResult {
    let exitCode: Int32
    let output: String
}

enum AgentController {
    static let label = "com.tomrhudson.inboxcourier.agent"

    static func isLoaded() -> Bool {
        run("/bin/launchctl", ["list", label]).exitCode == 0
    }

    static func runNow() -> CommandResult {
        run("/bin/launchctl", ["kickstart", "-k", "gui/\(getuid())/\(label)"])
    }

    static func reload() -> CommandResult {
        let plistPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(label).plist"
        _ = run("/bin/launchctl", ["bootout", "gui/\(getuid())", plistPath])
        return run("/bin/launchctl", ["bootstrap", "gui/\(getuid())", plistPath])
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
}
