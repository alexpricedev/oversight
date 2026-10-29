import Foundation

/// Everything the dashboard needs from GitHub. The app talks to this, and the
/// tests use a fake that returns fixture data instead of going to the network.
///
/// Calls take an `account` (the login whose token is in the Keychain) so an
/// organization's repositories can be read with the token of the account that
/// belongs to it.
protocol GitHubClientProtocol: Sendable {
    /// Every repository the account's token can see, including repositories
    /// owned by organizations the account belongs to. Archived repositories and
    /// forks are excluded.
    func listRepos(account: String) async throws -> [Repo]

    /// Organizations the account's token can see. Best effort: a token without
    /// organization access simply returns none.
    func organizations(account: String) async throws -> [Owner]

    /// The most recent workflow runs in a repository.
    func recentRuns(repo: RepoID, account: String) async throws -> [WorkflowRun]

    /// Open pull requests in one repository, including each head SHA so the CI
    /// status can be resolved.
    func openPullRequests(repo: RepoID, account: String) async throws -> [PullRequestRow]

    /// `owner` decides the search scope; `account` supplies the token.
    func openIssues(owner: Owner, account: String) async throws -> [IssueRow]

    /// The CI state of one commit, from the workflow runs for that head SHA.
    func ciRollup(repo: RepoID, account: String, headSHA: String) async throws -> CIRollup

    /// Checks a token before it is stored, and works out whether the owner is a
    /// user or an organization.
    func verifyOwner(login: String, token: String) async throws -> Owner

    func rateLimit(for account: String) async -> RateLimitInfo?
}
