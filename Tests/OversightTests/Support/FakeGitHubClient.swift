import Foundation
@testable import Oversight

actor FakeGitHubClient: GitHubClientProtocol {
    /// Keyed by account: every repository that account's token can see,
    /// including the ones owned by its organizations.
    var reposByOwner: [String: [Repo]]
    var runsByRepo: [RepoID: [WorkflowRun]]
    var pullRequestsByOwner: [String: [PullRequestRow]]
    var issuesByOwner: [String: [IssueRow]]
    var ciByKey: [String: CIRollup]
    var ownerErrors: [String: GitHubError]
    var repoErrors: [RepoID: GitHubError]
    var verifyKind: OwnerKind
    var rateLimitInfo: RateLimitInfo?

    private(set) var listRepoCalls = 0
    private(set) var runsRequests: [RepoID] = []
    private(set) var issueCalls: [IssueCall] = []
    private(set) var accountsUsed: Set<String> = []

    /// Holds the next `listRepos` call until `releaseListRepos`, so a test can
    /// click refresh while a pass is genuinely in flight.
    private var holdsListRepos = false
    private var listReposWaiters: [CheckedContinuation<Void, Never>] = []

    func holdListRepos() {
        holdsListRepos = true
    }

    func releaseListRepos() {
        holdsListRepos = false
        let waiters = listReposWaiters
        listReposWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }

    struct IssueCall: Equatable {
        let owner: String
        let kind: OwnerKind
        let account: String
    }

    init(
        reposByOwner: [String: [Repo]] = [:],
        runsByRepo: [RepoID: [WorkflowRun]] = [:],
        pullRequestsByOwner: [String: [PullRequestRow]] = [:],
        issuesByOwner: [String: [IssueRow]] = [:],
        ciByKey: [String: CIRollup] = [:],
        ownerErrors: [String: GitHubError] = [:],
        repoErrors: [RepoID: GitHubError] = [:],
        verifyKind: OwnerKind = .user,
        rateLimitInfo: RateLimitInfo? = nil
    ) {
        self.reposByOwner = reposByOwner
        self.runsByRepo = runsByRepo
        self.pullRequestsByOwner = pullRequestsByOwner
        self.issuesByOwner = issuesByOwner
        self.ciByKey = ciByKey
        self.ownerErrors = ownerErrors
        self.repoErrors = repoErrors
        self.verifyKind = verifyKind
        self.rateLimitInfo = rateLimitInfo
    }

    func setRepoError(_ error: GitHubError?, for repo: RepoID) {
        repoErrors[repo] = error
    }

    func setOwnerError(_ error: GitHubError?, for owner: String) {
        ownerErrors[owner] = error
    }

    func setRepos(_ repos: [Repo], for owner: String) {
        reposByOwner[owner] = repos
    }

    func clearRecordings() {
        runsRequests = []
        issueCalls = []
        accountsUsed = []
    }

    func listRepos(account: Owner) async throws -> [Repo] {
        listRepoCalls += 1
        accountsUsed.insert(account.login)
        if holdsListRepos {
            await withCheckedContinuation { listReposWaiters.append($0) }
        }
        if let error = ownerErrors[account.login] { throw error }
        return reposByOwner[account.login] ?? []
    }

    func recentRuns(repo: RepoID, account: String) async throws -> [WorkflowRun] {
        runsRequests.append(repo)
        accountsUsed.insert(account)
        if let error = repoErrors[repo] { throw error }
        if let error = ownerErrors[account] { throw error }
        return runsByRepo[repo] ?? []
    }

    func openPullRequests(repo: RepoID, account: String) async throws -> [PullRequestRow] {
        accountsUsed.insert(account)
        if let error = repoErrors[repo] { throw error }
        if let error = ownerErrors[account] { throw error }
        return pullRequestsByOwner.values.joined().filter { $0.repo == repo }
    }

    func openIssues(owner: Owner, account: String) async throws -> [IssueRow] {
        issueCalls.append(IssueCall(owner: owner.login, kind: owner.kind, account: account))
        accountsUsed.insert(account)
        if let error = ownerErrors[owner.login] { throw error }
        if let error = ownerErrors[account] { throw error }
        return issuesByOwner[owner.login] ?? []
    }

    func ciRollup(repo: RepoID, account: String, headSHA: String) async throws -> CIRollup {
        accountsUsed.insert(account)
        if let error = ownerErrors[account] { throw error }
        return ciByKey["\(repo.slug)@\(headSHA)"] ?? .none
    }

    func verifyOwner(login: String, token _: String) async throws -> Owner {
        if let error = ownerErrors[login] { throw error }
        return Owner(login: login, kind: verifyKind)
    }

    func rateLimit(for _: String) async -> RateLimitInfo? {
        rateLimitInfo
    }
}
