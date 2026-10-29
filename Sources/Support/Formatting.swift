import Foundation

protocol Clocking: Sendable {
    var now: Date { get }
}

struct SystemClock: Clocking {
    var now: Date {
        Date()
    }
}

enum RelativeTime {
    /// "just now", "3m ago", "2h ago", "4d ago", "3w ago", "5mo ago".
    static func ago(_ date: Date, now: Date) -> String {
        let delta = max(0, now.timeIntervalSince(date))
        switch delta {
        case ..<45:
            return "just now"
        case ..<3600:
            return "\(Int(delta / 60))m ago"
        case ..<86400:
            return "\(Int(delta / 3600))h ago"
        case ..<604_800:
            return "\(Int(delta / 86400))d ago"
        case ..<2_592_000:
            return "\(Int(delta / 604_800))w ago"
        default:
            return "\(Int(delta / 2_592_000))mo ago"
        }
    }
}

enum Elapsed {
    /// A ticking clock: "0:07", "12:05", "1:02:33".
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// A finished duration: "7s", "1m 04s", "2h 05m".
    static func short(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded())
        if total < 60 { return "\(total)s" }
        if total < 3600 {
            return String(format: "%dm %02ds", total / 60, total % 60)
        }
        return String(format: "%dh %02dm", total / 3600, (total % 3600) / 60)
    }
}

enum GitHubDates {
    static func parse(_ string: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: string) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: string)
    }
}
