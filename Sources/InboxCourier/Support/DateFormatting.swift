import Foundation

enum DateFormatting {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static func relative(_ date: Date?) -> String {
        guard let date else {
            return "Never"
        }

        return relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    static func time(_ date: Date?) -> String {
        guard let date else {
            return "Never"
        }

        return absoluteFormatter.string(from: date)
    }
}
