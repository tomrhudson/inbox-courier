import AppKit
import SwiftUI

struct StatusMenuView: View {
    @ObservedObject var store: StatusStore

    var body: some View {
        let status = store.snapshot.status

        VStack(alignment: .leading, spacing: 0) {
            StatusHeaderView(snapshot: store.snapshot)

            Divider()

            StatusLine(label: "Pending", value: "\(status?.pendingAfterRun ?? status?.pendingBeforeRun ?? 0)")
            StatusLine(label: "Last run", value: DateFormatting.time(status?.lastFinishedAt))
            StatusLine(label: "Migrated", value: "\(status?.migratedCount ?? 0)")
            StatusLine(label: "Agent", value: store.snapshot.isLoaded ? "Loaded" : "Not loaded")
            StatusLine(label: "Launch at login", value: store.launchAtLoginStatus)

            if let error = status?.lastError, !error.isEmpty {
                Divider()
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: 260, alignment: .leading)
                    .padding(.vertical, 4)
            }

            if let message = store.lastCommandMessage {
                Divider()
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: 260, alignment: .leading)
                    .padding(.vertical, 4)
            }

            Divider()

            Button("Run Now") {
                store.runNow()
            }
            Button("Refresh") {
                store.refresh()
            }
            Button("Reload Agent") {
                store.reloadAgent()
            }
            Toggle("Launch at Login", isOn: Binding(
                get: { store.launchAtLoginEnabled },
                set: { store.setLaunchAtLogin($0) }
            ))

            Divider()

            Button("Open Reminders") {
                store.openReminders()
            }
            Button("Open Things") {
                store.openThings()
            }
            Button("View Logs") {
                store.openLogs()
            }
            Button("View Status") {
                store.openStatusFile()
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .frame(width: 280)
    }
}

private struct StatusHeaderView: View {
    let snapshot: AgentSnapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: imageName)
                .foregroundStyle(color)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.bottom, 6)
    }

    private var title: String {
        switch snapshot.health {
        case .healthy:
            return "Sync Healthy"
        case .pending:
            return "Items Pending"
        case .running:
            return "Sync Running"
        case .stale:
            return "Sync Stale"
        case .error:
            return "Needs Attention"
        case .unknown:
            return "Status Unknown"
        }
    }

    private var subtitle: String {
        let lastFinished = snapshot.status?.lastFinishedAt

        switch snapshot.health {
        case .healthy, .pending:
            return "Last run \(DateFormatting.relative(lastFinished))"
        case .running:
            return "Started \(DateFormatting.relative(snapshot.status?.lastStartedAt))"
        case .stale:
            return "Last run \(DateFormatting.relative(lastFinished))"
        case .error:
            return snapshot.isLoaded ? "Last run failed" : "Agent not loaded"
        case .unknown:
            return "Waiting for first status"
        }
    }

    private var imageName: String {
        switch snapshot.health {
        case .healthy:
            return "checkmark.circle.fill"
        case .pending:
            return "tray.full.fill"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .stale:
            return "clock.badge.exclamationmark.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch snapshot.health {
        case .healthy:
            return .green
        case .pending:
            return .blue
        case .running:
            return .accentColor
        case .stale:
            return .orange
        case .error:
            return .red
        case .unknown:
            return .secondary
        }
    }
}

private struct StatusLine: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .lineLimit(1)
        }
        .font(.callout)
        .padding(.vertical, 2)
    }
}
