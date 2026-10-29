import Foundation

struct RepoPayload: Decodable {
    struct OwnerPayload: Decodable {
        let login: String
    }

    let name: String
    let owner: OwnerPayload
    let isPrivate: Bool
    let isFork: Bool
    let isArchived: Bool
    let pushedAt: Date?
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case name, owner
        case isPrivate = "private"
        case isFork = "fork"
        case isArchived = "archived"
        case pushedAt = "pushed_at"
        case defaultBranch = "default_branch"
    }

    func toRepo() -> Repo? {
        guard !name.isEmpty, !owner.login.isEmpty else { return nil }
        return Repo(
            id: RepoID(owner: owner.login, name: name),
            isPrivate: isPrivate,
            isFork: isFork,
            isArchived: isArchived,
            pushedAt: pushedAt,
            defaultBranch: defaultBranch
        )
    }
}

struct UserPayload: Decodable {
    let login: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case login, type
    }
}

struct WorkflowRunsResponse: Decodable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

struct SearchResponse: Decodable {
    let totalCount: Int
    let items: [SearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct SearchItem: Decodable {
    struct User: Decodable {
        let login: String
    }

    struct Label: Decodable {
        let name: String
    }

    struct PullRequestLink: Decodable {
        struct Head: Decodable {
            let sha: String
        }

        let head: Head?
    }

    let number: Int
    let title: String
    let htmlURL: URL
    let user: User?
    let createdAt: Date
    let updatedAt: Date
    let draft: Bool?
    let labels: [Label]
    let pullRequest: PullRequestLink?
    let repositoryURL: URL

    enum CodingKeys: String, CodingKey {
        case number, title, user, draft, labels
        case htmlURL = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case pullRequest = "pull_request"
        case repositoryURL = "repository_url"
    }

    var repoID: RepoID? {
        let parts = repositoryURL.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        return RepoID(owner: parts[parts.count - 2], name: parts[parts.count - 1])
    }

    func toPullRequestRow() -> PullRequestRow? {
        guard let repoID else { return nil }
        return PullRequestRow(
            repo: repoID,
            number: number,
            title: title,
            author: user?.login ?? "someone",
            createdAt: createdAt,
            isDraft: draft ?? false,
            headSHA: pullRequest?.head?.sha ?? "",
            url: htmlURL
        )
    }

    func toIssueRow() -> IssueRow? {
        guard pullRequest == nil, let repoID else { return nil }
        return IssueRow(
            repo: repoID,
            number: number,
            title: title,
            labels: labels.map(\.name),
            createdAt: createdAt,
            url: htmlURL
        )
    }
}

/// The shape of GitHub's error bodies.
struct ErrorPayload: Decodable {
    let message: String
}

/// One entry from `GET /repos/{owner}/{repo}/pulls?state=open`. Unlike the
/// issue-search shape, this includes the head SHA, which CI lookup needs.
struct PullPayload: Decodable {
    struct Head: Decodable {
        let sha: String
    }

    let number: Int
    let title: String
    let htmlURL: URL
    let user: SearchItem.User?
    let createdAt: Date
    let draft: Bool?
    let labels: [SearchItem.Label]
    let head: Head?

    enum CodingKeys: String, CodingKey {
        case number, title, user, draft, labels, head
        case htmlURL = "html_url"
        case createdAt = "created_at"
    }
}

extension PullPayload {
    func toRow(repo: RepoID) -> PullRequestRow {
        PullRequestRow(
            repo: repo,
            number: number,
            title: title,
            author: user?.login ?? "someone",
            createdAt: createdAt,
            isDraft: draft ?? false,
            headSHA: head?.sha ?? "",
            url: htmlURL
        )
    }
}
