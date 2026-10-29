import Foundation

/// Everything the dashboard needs from GitHub. The app talks to this, and the
/// tests use a fake that returns fixture data instead of going to the network.
protocol GitHubClientProtocol: Sendable {
    /// Repositories owned by `owner` that this owner's token can see. Archived
    /// repositories and forks are excluded.
    func listRepos(owner: Owner) async throws -> [Repo]

    /// The most recent workflow runs in a repository.
    func recentRuns(repo: RepoID, owner: String) async throws -> [WorkflowRun]

    /// Open pull requests in one repository, including each head SHA so the CI
    /// status can be resolved.
    func openPullRequests(repo: RepoID, owner: String) async throws -> [PullRequestRow]

    func openIssues(owner: Owner) async throws -> [IssueRow]

    /// The CI state of one commit, from the workflow runs for that head SHA.
    func ciRollup(repo: RepoID, owner: String, headSHA: String) async throws -> CIRollup

    /// Checks a token before it is stored, and works out whether the owner is a
    /// user or an organization.
    func verifyOwner(login: String, token: String) async throws -> Owner

    func rateLimit(for owner: String) async -> RateLimitInfo?
}
