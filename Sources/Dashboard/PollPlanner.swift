import Foundation

/// One independently polled thing.
enum PollKey: Hashable {
    case repos(String)
    case search(String)
    case runs(RepoID)
    case ci(RepoID, String)

    var sortKey: String {
        switch self {
        case let .repos(owner): "0:\(owner)"
        case let .search(owner): "1:\(owner)"
        case let .runs(repo): "2:\(repo.slug)"
        case let .ci(repo, sha): "3:\(repo.slug):\(sha)"
        }
    }

    var owner: String {
        switch self {
        case let .repos(owner), let .search(owner): owner
        case let .runs(repo), let .ci(repo, _): repo.owner
        }
    }

    var repo: RepoID? {
        switch self {
        case .repos, .search: nil
        case let .runs(repo), let .ci(repo, _): repo
        }
    }
}

/// Tracks when each key is next due. Deliberately pure and date-driven, so the
/// polling rules can be tested without waiting for real time to pass.
struct PollPlanner {
    private(set) var dueAt: [PollKey: Date] = [:]

    mutating func schedule(_ key: PollKey, in interval: TimeInterval, from now: Date) {
        dueAt[key] = now.addingTimeInterval(max(1, interval))
    }

    mutating func schedule(_ key: PollKey, at date: Date) {
        dueAt[key] = date
    }

    /// A key that has never been polled is due immediately.
    func isDue(_ key: PollKey, at now: Date) -> Bool {
        (dueAt[key] ?? .distantPast) <= now
    }

    func dueKeys(at now: Date) -> [PollKey] {
        dueAt.filter { $0.value <= now }
            .keys
            .sorted { $0.sortKey < $1.sortKey }
    }

    func nextWake(after now: Date) -> Date? {
        dueAt.values.filter { $0 > now }.min()
    }

    mutating func markAllDue(at now: Date) {
        for key in dueAt.keys {
            dueAt[key] = now
        }
    }

    /// Drops keys that no longer correspond to a configured owner or repo.
    mutating func retain(_ keys: Set<PollKey>) {
        dueAt = dueAt.filter { keys.contains($0.key) }
    }

    var keys: Set<PollKey> {
        Set(dueAt.keys)
    }

    var isEmpty: Bool {
        dueAt.isEmpty
    }
}
