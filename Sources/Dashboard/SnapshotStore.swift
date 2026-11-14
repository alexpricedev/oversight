import Foundation

/// The dashboard's last data, saved so the window opens already filled while
/// the first refresh runs. It holds repository names and pull request and
/// issue titles, never tokens.
struct DashboardSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var version = Self.currentVersion
    var savedAt: Date
    var reposByOwner: [String: [Repo]]
    var orgAccounts: [String: String]
    var discoveredOrgs: [String: String]
    var runsByRepo: [RepoID: [WorkflowRun]]
    var pullRequestsByOwner: [String: [PullRequestRow]]
    var issuesByOwner: [String: [IssueRow]]
    var ciByRepo: [RepoID: [String: CIRollup]]
}

/// Reads and writes the snapshot file. A missing, unreadable or
/// older-format file counts as no snapshot.
struct SnapshotStore: Sendable {
    let fileURL: URL

    /// `~/Library/Application Support/Oversight/snapshot.json`.
    static func applicationSupport() -> SnapshotStore? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return SnapshotStore(
            fileURL: base
                .appendingPathComponent("Oversight", isDirectory: true)
                .appendingPathComponent("snapshot.json")
        )
    }

    func load() -> DashboardSnapshot? {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(DashboardSnapshot.self, from: data),
              snapshot.version == DashboardSnapshot.currentVersion
        else { return nil }
        return snapshot
    }

    func save(_ snapshot: DashboardSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
