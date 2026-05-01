import Foundation

enum AgentHealth {
    case healthy
    case pending
    case running
    case stale
    case error
    case unknown
}

struct AgentStatus: Decodable {
    let label: String?
    let state: String
    let lastStartedAt: Date?
    let lastFinishedAt: Date?
    let lastExitCode: Int?
    let pendingBeforeRun: Int
    let pendingAfterRun: Int?
    let migratedCount: Int
    let lastError: String?
    let logFile: String?
    let scriptPath: String?
}

struct AgentSnapshot {
    var status: AgentStatus?
    var isLoaded: Bool
    var statusFileExists: Bool
    var generatedAt: Date

    var health: AgentHealth {
        guard isLoaded else {
            return .error
        }

        guard let status else {
            return statusFileExists ? .unknown : .stale
        }

        if status.state == "running" {
            return .running
        }

        if status.state == "failed" || (status.lastExitCode ?? 0) != 0 {
            return .error
        }

        guard let finishedAt = status.lastFinishedAt else {
            return .unknown
        }

        if generatedAt.timeIntervalSince(finishedAt) > 30 * 60 {
            return .stale
        }

        if (status.pendingAfterRun ?? status.pendingBeforeRun) > 0 {
            return .pending
        }

        return .healthy
    }
}
