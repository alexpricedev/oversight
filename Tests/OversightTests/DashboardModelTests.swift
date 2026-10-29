import Foundation
@testable import Oversight
import Testing

@MainActor
@Suite("Dashboard model")
struct DashboardModelTests {
    private func makeSettings(owners: [Owner] = [Owner(login: "alexpricedev", kind: .user)]) -> AppSettings {
        let defaults = UserDefaults(suiteName: "com.chptrs.oversight.tests.\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults, seedDefaultOwner: false)
        for owner in owners {
            settings.addOwner(owner)
        }
        return settings
    }

    private func makeModel(client: FakeGitHubClient, settings: AppSettings) -> DashboardModel {
        DashboardModel(client: client, settings: settings, clock: TestClock())
    }

    private func richClient() throws -> FakeGitHubClient {
        FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas, Sample.altex]],
            runsByRepo: [
                Sample.atlas.id: [
                    Sample.run(id: 1, status: "in_progress", conclusion: nil, startedAt: Sample.date("2026-10-29T09:50:00Z")),
                    Sample.run(id: 2, branch: "feature/sidebar", status: "queued", conclusion: nil, startedAt: Sample.date("2026-10-29T09:55:00Z")),
                    Sample.run(id: 3, startedAt: Sample.date("2026-10-29T09:00:00Z")),
                ],
            ],
            pullRequestsByOwner: ["alexpricedev": [Sample.pullRequest()]],
            issuesByOwner: ["alexpricedev": [Sample.issue()]],
            ciByKey: [
                "alexpricedev/atlas@9999999999999999999999999999999999999999": .success,
            ]
        )
    }

    @Test("One refresh fills the Actions feed, pull requests and issues")
    func refreshPopulatesSections() async throws {
        let client = try richClient()
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.actionRows.count == 3)
        #expect(model.actionRows.map(\.id) == [2, 1, 3])
        #expect(model.actionRows.first?.workflowName == "CI")
        #expect(model.pullRequestRows.count == 1)
        #expect(model.issueRows.count == 1)
        #expect(try model.ciStatus(for: #require(model.pullRequestRows.first)) == .success)
        #expect(model.lastRefreshed != nil)
        #expect(model.ownerBanners.isEmpty)
        #expect(model.repoWarning(for: Sample.atlas.id) == nil)
    }

    @Test("The feed is the newest 25 runs, first in first out")
    func feedKeepsTheNewest25() async {
        let start = Sample.date("2026-10-01T00:00:00Z")
        let runs = (1 ... 30).map { index in
            Sample.run(id: Int64(index), startedAt: start.addingTimeInterval(TimeInterval(index) * 60))
        }
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            runsByRepo: [Sample.atlas.id: runs]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.actionRows.count == 25)
        #expect(model.actionRows.first?.id == 30)
        #expect(model.actionRows.last?.id == 6)
    }

    @Test("A run still going stays in the feed even when newer runs push it down")
    func runningRunsArePinned() async {
        let start = Sample.date("2026-10-01T00:00:00Z")
        var runs = (1 ... 30).map { index in
            Sample.run(id: Int64(index), startedAt: start.addingTimeInterval(TimeInterval(index) * 60))
        }
        runs.append(
            Sample.run(
                id: 999,
                status: "in_progress",
                conclusion: nil,
                startedAt: start.addingTimeInterval(-3600)
            )
        )
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            runsByRepo: [Sample.atlas.id: runs]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.actionRows.count == 25)
        #expect(model.actionRows.contains { $0.id == 999 })
        #expect(model.actionRows.first?.id == 30)
    }

    @Test("Owner and repo-name filters narrow every section")
    func filters() async {
        let client = FakeGitHubClient(
            reposByOwner: [
                "alexpricedev": [Sample.atlas],
                "tycho-station": [Repo(id: RepoID(owner: "tycho-station", name: "rocinante"))],
            ],
            runsByRepo: [
                Sample.atlas.id: [Sample.run(id: 1, status: "in_progress", conclusion: nil)],
                RepoID(owner: "tycho-station", name: "rocinante"): [Sample.run(id: 2, status: "queued", conclusion: nil)],
            ],
            pullRequestsByOwner: ["alexpricedev": [Sample.pullRequest()]]
        )
        let settings = makeSettings(owners: [
            Owner(login: "alexpricedev", kind: .user),
            Owner(login: "tycho-station", kind: .organization),
        ])
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()
        #expect(model.actionRows.count == 2)
        #expect(model.pullRequestRows.count == 1)

        model.ownerFilter = "tycho-station"
        #expect(model.actionRows.map(\.repo.slug) == ["tycho-station/rocinante"])
        #expect(model.pullRequestRows.isEmpty)

        model.ownerFilter = nil
        model.repoFilter = "rocinante"
        #expect(model.actionRows.map(\.repo.slug) == ["tycho-station/rocinante"])

        model.repoFilter = "ATLAS"
        #expect(model.actionRows.map(\.repo.slug) == ["alexpricedev/atlas"])
        model.repoFilter = ""
        #expect(model.actionRows.count == 2)
    }

    @Test("A hidden repo disappears from every section and is not polled")
    func hiddenRepos() async throws {
        let client = try richClient()
        let settings = makeSettings()
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()
        #expect(model.actionRows.count == 3)

        settings.hide("alexpricedev/atlas")
        await model.settingsDidChange()

        #expect(model.actionRows.isEmpty)
        #expect(model.pullRequestRows.isEmpty)
        #expect(model.issueRows.isEmpty)
        #expect(model.knownRepos.contains { $0.id == Sample.atlas.id })
    }

    @Test("Repos that are not listed never reach a section")
    func unlistedReposAreExcluded() async {
        let archived = Repo(
            id: RepoID(owner: "alexpricedev", name: "textjoy"),
            isArchived: true
        )
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            runsByRepo: [
                archived.id: [Sample.run(id: 1)],
                Sample.atlas.id: [Sample.run(id: 2)],
            ],
            pullRequestsByOwner: ["alexpricedev": [
                Sample.pullRequest(repo: archived.id, number: 1),
                Sample.pullRequest(repo: Sample.atlas.id, number: 2),
            ]],
            issuesByOwner: ["alexpricedev": [
                Sample.issue(repo: archived.id, number: 3),
                Sample.issue(repo: Sample.atlas.id, number: 4),
            ]]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.actionRows.allSatisfy { $0.repo == Sample.atlas.id })
        #expect(model.pullRequestRows.allSatisfy { $0.repo == Sample.atlas.id })
        #expect(model.issueRows.allSatisfy { $0.repo == Sample.atlas.id })
        #expect(model.issueRows.count == 1)
    }

    @Test("A repo archived mid-session disappears and stops being polled")
    func archivingRemovesRepo() async {
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas, Sample.altex]],
            runsByRepo: [
                Sample.atlas.id: [Sample.run(id: 1)],
                Sample.altex.id: [Sample.run(id: 2)],
            ]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()
        #expect(model.actionRows.count == 2)

        await client.setRepos([Sample.atlas], for: "alexpricedev")
        await model.refreshAll()

        #expect(model.knownRepos.map(\.id) == [Sample.atlas.id])
        #expect(model.actionRows.map(\.repo) == [Sample.atlas.id])
    }

    @Test("A rejected token puts a banner on its owner")
    func tokenFailureBanner() async {
        let client = FakeGitHubClient(
            ownerErrors: ["alexpricedev": .unauthorized("Bad credentials")]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.ownerBanners.count == 1)
        #expect(model.ownerBanners.first?.owner.login == "alexpricedev")
        #expect(model.ownerBanners.first?.message == "Bad credentials")
        #expect(model.actionRows.isEmpty)
    }

    @Test("A rate-limited owner gets a banner too")
    func rateLimitBanner() async {
        let reset = Sample.date("2026-10-29T13:00:00Z")
        let client = FakeGitHubClient(
            ownerErrors: ["alexpricedev": .rateLimited(reset: reset)]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.ownerBanners.count == 1)
        #expect(model.ownerBanners.first?.message.contains("Rate limited") == true)
    }

    @Test("A failing repo call keeps the rows it already had and flags the repo")
    func repoFailureKeepsPreviousData() async throws {
        let client = try richClient()
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()
        #expect(model.actionRows.count == 3)

        await client.setRepoError(.server(status: 500, message: "boom"), for: Sample.atlas.id)
        await model.refreshAll()

        #expect(model.actionRows.count == 3)
        #expect(model.repoWarning(for: Sample.atlas.id) != nil)
    }

    @Test("Replacing a token clears the old banner")
    func replacingTokenClearsBanner() async {
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            ownerErrors: ["alexpricedev": .unauthorized("Bad credentials")]
        )
        let settings = makeSettings()
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()
        #expect(model.ownerBanners.count == 1)

        await client.setOwnerError(nil, for: "alexpricedev")
        await model.settingsDidChange()

        #expect(model.ownerBanners.isEmpty)
    }

    @Test("Pull requests are capped at the newest 25 overall")
    func pullRequestsCappedAt25() async {
        let start = Sample.date("2026-10-01T09:00:00Z")
        let pullRequests = (1 ... 30).map { index in
            Sample.pullRequest(
                number: index,
                title: "PR \(index)",
                createdAt: start.addingTimeInterval(TimeInterval(index) * 86400)
            )
        }
        let client = FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas]],
            pullRequestsByOwner: ["alexpricedev": pullRequests]
        )
        let model = makeModel(client: client, settings: makeSettings())

        await model.refreshAll()

        #expect(model.pullRequestRows.count == 30)
        #expect(model.latestPullRequests.count == 25)
        #expect(model.latestPullRequests.first?.number == 30)
        #expect(model.latestPullRequests.last?.number == 6)
    }

    // MARK: - Organizations

    private func organizationClient() -> FakeGitHubClient {
        let answerRank = Repo(
            id: RepoID(owner: "wearenaitiv", name: "answerrank"),
            isPrivate: true,
            pushedAt: Sample.date("2026-10-29T08:00:00Z")
        )
        return FakeGitHubClient(
            reposByOwner: ["alexpricedev": [Sample.atlas, answerRank]],
            runsByRepo: [
                Sample.atlas.id: [Sample.run(id: 1)],
                answerRank.id: [Sample.run(id: 2)],
            ],
            pullRequestsByOwner: [
                "wearenaitiv": [Sample.pullRequest(repo: answerRank.id, number: 7)],
            ],
            issuesByOwner: [
                "wearenaitiv": [Sample.issue(repo: answerRank.id, number: 8)],
            ]
        )
    }

    @Test("Organization repositories stay out until the organization is switched on")
    func organizationReposAreOptIn() async {
        let client = organizationClient()
        let settings = makeSettings()
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()

        #expect(model.actionRows.map(\.repo.slug) == ["alexpricedev/atlas"])
        #expect(model.pullRequestRows.isEmpty)
        #expect(model.issueRows.isEmpty)
        #expect(model.accountLogin(for: "wearenaitiv") == nil)

        // The organization is still offered in Settings, with what it contains.
        #expect(model.organizations.map(\.owner.login) == ["wearenaitiv"])
        #expect(model.organizations.first?.repoCount == 1)
        #expect(model.organizations.first?.isIncluded == false)
        #expect(model.organizations.first?.account == "alexpricedev")

        let runsBefore = await client.runsRequests
        #expect(!runsBefore.contains(RepoID(owner: "wearenaitiv", name: "answerrank")))

        settings.includeOrg("wearenaitiv")
        await model.settingsDidChange()

        #expect(model.actionRows.map(\.repo.slug).sorted() == [
            "alexpricedev/atlas",
            "wearenaitiv/answerrank",
        ])
        #expect(model.pullRequestRows.map(\.repo.slug) == ["wearenaitiv/answerrank"])
        #expect(model.issueRows.map(\.repo.slug) == ["wearenaitiv/answerrank"])
        #expect(model.accountLogin(for: "wearenaitiv") == "alexpricedev")
        #expect(model.organizations.first?.isIncluded == true)
        #expect(model.ownerBanners.isEmpty)
    }

    @Test("Organization rows are read with the account's token and an org: search")
    func organizationUsesTheAccountToken() async {
        let client = organizationClient()
        let settings = makeSettings()
        settings.includeOrg("wearenaitiv")
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()

        let calls = await client.issueCalls
        let orgCall = calls.first { $0.owner == "wearenaitiv" }
        #expect(orgCall?.kind == .organization)
        #expect(orgCall?.account == "alexpricedev")

        let accounts = await client.accountsUsed
        #expect(accounts == ["alexpricedev"])
    }

    @Test("Switching an organization off stops polling its repositories")
    func excludingOrganizationStopsPolling() async {
        let client = organizationClient()
        let settings = makeSettings()
        settings.includeOrg("wearenaitiv")
        let model = makeModel(client: client, settings: settings)

        await model.refreshAll()
        #expect(model.actionRows.count == 2)

        await client.clearRecordings()
        settings.excludeOrg("wearenaitiv")
        await model.settingsDidChange()

        let requests = await client.runsRequests
        #expect(!requests.contains(RepoID(owner: "wearenaitiv", name: "answerrank")))
        #expect(model.actionRows.map(\.repo.slug) == ["alexpricedev/atlas"])
        #expect(model.pullRequestRows.isEmpty)
        #expect(model.organizations.map(\.owner.login) == ["wearenaitiv"])
    }
}
