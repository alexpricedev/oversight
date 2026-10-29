import Foundation

/// Serves `DemoData` instead of GitHub, so the app can be run with realistic
/// content and no token. Selected with the `--demo` launch argument.
actor DemoGitHubClient: GitHubClientProtocol {
    private let data = DemoData()

    func listRepos(account: String) async throws -> [Repo] {
        data.repos.filter { $0.owner.caseInsensitiveCompare(account) == .orderedSame }
    }

    func organizations(account _: String) async throws -> [Owner] {
        []
    }

    func recentRuns(repo: RepoID, account _: String) async throws -> [WorkflowRun] {
        data.runs[repo] ?? []
    }

    func openPullRequests(repo: RepoID, account: String) async throws -> [PullRequestRow] {
        (data.pullRequests[account] ?? []).filter { $0.repo == repo }
    }

    func openIssues(owner: Owner, account _: String) async throws -> [IssueRow] {
        data.issues[owner.login] ?? []
    }

    func ciRollup(repo: RepoID, account _: String, headSHA: String) async throws -> CIRollup {
        data.ci["\(repo.slug)@\(headSHA)"] ?? .none
    }

    func verifyOwner(login: String, token _: String) async throws -> Owner {
        Owner(login: login, kind: .user)
    }

    func rateLimit(for _: String) async -> RateLimitInfo? {
        data.rateLimit
    }
}

/// Demo mode never touches the Keychain or the network.
struct DemoTokenStore: TokenStore {
    func token(for _: String) throws -> String? {
        "demo-token"
    }

    func save(_: String, for _: String) throws {}

    func delete(for _: String) throws {}
}
