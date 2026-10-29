import Foundation
@testable import Oversight

actor FakeGitHubClient: GitHubClientProtocol {
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

    func listRepos(owner: Owner) async throws -> [Repo] {
        listRepoCalls += 1
        if let error = ownerErrors[owner.login] { throw error }
        return reposByOwner[owner.login] ?? []
    }

    func recentRuns(repo: RepoID, owner: String) async throws -> [WorkflowRun] {
        if let error = repoErrors[repo] { throw error }
        if let error = ownerErrors[owner] { throw error }
        return runsByRepo[repo] ?? []
    }

    func openPullRequests(repo: RepoID, owner: String) async throws -> [PullRequestRow] {
        if let error = repoErrors[repo] { throw error }
        if let error = ownerErrors[owner] { throw error }
        return (pullRequestsByOwner[owner] ?? []).filter { $0.repo == repo }
    }

    func openIssues(owner: Owner) async throws -> [IssueRow] {
        if let error = ownerErrors[owner.login] { throw error }
        return issuesByOwner[owner.login] ?? []
    }

    func ciRollup(repo: RepoID, owner: String, headSHA: String) async throws -> CIRollup {
        if let error = ownerErrors[owner] { throw error }
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
