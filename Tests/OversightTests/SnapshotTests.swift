import Foundation
@testable import Oversight
import Testing

@MainActor
@Suite("Snapshot")
struct SnapshotTests {
    private let savedAt = Sample.date("2026-10-29T11:00:00Z")
    private let headSHA = "9999999999999999999999999999999999999999"

    private func makeStore() -> SnapshotStore {
        SnapshotStore(
            fileURL: FileManager.default.temporaryDirectory
                .appendingPathComponent("oversight-tests-\(UUID().uuidString)", isDirectory: true)
                .appendingPathComponent("snapshot.json")
        )
    }

    private func makeSettings(owners: [Owner] = [Owner(login: "alexpricedev", kind: .user)]) -> AppSettings {
        let defaults = UserDefaults(suiteName: "com.chptrs.oversight.tests.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults, seedDefaultOwner: false)
        for owner in owners {
            settings.addOwner(owner)
        }
        return settings
    }

    private func snapshot() -> DashboardSnapshot {
        let stranger = Repo(id: RepoID(owner: "someone-else", name: "theirs"), pushedAt: savedAt)
        return DashboardSnapshot(
            savedAt: savedAt,
            reposByOwner: [
                "alexpricedev": [Sample.atlas, Sample.altex],
                "someone-else": [stranger],
            ],
            orgAccounts: [:],
            discoveredOrgs: [:],
            runsByRepo: [
                Sample.atlas.id: [Sample.run(id: 1), Sample.run(id: 2, status: "in_progress", conclusion: nil)],
                stranger.id: [Sample.run(id: 3)],
            ],
            pullRequestsByOwner: ["alexpricedev": [Sample.pullRequest(headSHA: headSHA)]],
            issuesByOwner: ["alexpricedev": [Sample.issue()]],
            ciByRepo: [Sample.atlas.id: [headSHA: .failure]]
        )
    }

    @Test("A snapshot survives a save and load")
    func roundTrip() throws {
        let store = makeStore()
        try store.save(snapshot())
        #expect(store.load() == snapshot())
    }

    @Test("A missing or unreadable file counts as no snapshot")
    func unreadableFile() throws {
        let store = makeStore()
        #expect(store.load() == nil)

        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not json".utf8).write(to: store.fileURL)
        #expect(store.load() == nil)
    }

    @Test("The window opens with the last saved data before any request")
    func restoresBeforeRefreshing() async throws {
        let store = makeStore()
        try store.save(snapshot())
        let client = FakeGitHubClient()

        let model = DashboardModel(client: client, settings: makeSettings(), clock: TestClock(), snapshotStore: store)

        #expect(model.actionRows.map(\.id).sorted() == [1, 2])
        #expect(model.pullRequestRows.count == 1)
        #expect(model.issueRows.count == 1)
        #expect(try model.ciStatus(for: #require(model.pullRequestRows.first)) == .failure)
        #expect(model.lastRefreshed == savedAt)
        let calls = await client.listRepoCalls
        #expect(calls == 0)
    }

    @Test("An account removed since the last launch is dropped on load")
    func dropsRemovedAccounts() throws {
        let store = makeStore()
        try store.save(snapshot())

        let model = DashboardModel(client: FakeGitHubClient(), settings: makeSettings(), clock: TestClock(), snapshotStore: store)

        #expect(model.knownRepos.map(\.id) == [Sample.altex.id, Sample.atlas.id])
        #expect(!model.actionRows.contains { $0.id == 3 })
    }

    @Test("A refresh saves the snapshot, at most once a minute")
    func refreshSaves() async throws {
        let store = makeStore()
        let clock = TestClock()
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            runsByRepo: [Sample.atlas.id: [Sample.run(id: 1)]],
            pullRequestsByOwner: ["alexpricedev": [Sample.pullRequest()]]
        )
        let model = DashboardModel(client: client, settings: makeSettings(), clock: clock, snapshotStore: store)

        await model.refreshAll()
        await model.flushSnapshot()
        let saved = try #require(store.load())
        #expect(saved.savedAt == clock.now)
        #expect(saved.runsByRepo[Sample.atlas.id]?.map(\.id) == [1])
        #expect(saved.pullRequestsByOwner["alexpricedev"]?.count == 1)

        // A second pass inside the minute leaves the file alone.
        try FileManager.default.removeItem(at: store.fileURL)
        clock.advance(30)
        await model.refreshAll()
        await model.flushSnapshot()
        #expect(store.load() == nil)

        clock.advance(31)
        await model.refreshAll()
        await model.flushSnapshot()
        #expect(store.load()?.savedAt == clock.now)
    }

    @Test("Closing the window saves straight away")
    func pauseSaves() async throws {
        let store = makeStore()
        let client = FakeGitHubClient(reposByOwner: ["alexpricedev": [Sample.atlas]])
        let model = DashboardModel(client: client, settings: makeSettings(), clock: TestClock(), snapshotStore: store)
        await model.refreshAll()
        await model.flushSnapshot()
        try FileManager.default.removeItem(at: store.fileURL)

        model.pausePolling()
        await model.flushSnapshot()

        #expect(store.load() != nil)
    }
}
