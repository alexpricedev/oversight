import Foundation
@testable import Oversight

enum Sample {
    static func date(_ string: String) -> Date {
        GitHubDates.parse(string)!
    }

    static let atlas = Repo(
        id: RepoID(owner: "alexpricedev", name: "atlas"),
        isPrivate: true,
        pushedAt: date("2026-10-28T10:00:00Z")
    )

    static let altex = Repo(
        id: RepoID(owner: "alexpricedev", name: "altex"),
        isPrivate: false,
        pushedAt: date("2026-08-01T10:00:00Z")
    )

    static func run(
        id: Int64,
        workflow: String = "CI",
        branch: String = "main",
        sha: String = "abc1234567890abcdef1234567890abcdef12345",
        status: String = "completed",
        conclusion: String? = "success",
        startedAt: Date = date("2026-10-29T09:00:00Z"),
        updatedAt: Date = date("2026-10-29T09:05:00Z"),
        message: String? = "A commit"
    ) -> WorkflowRun {
        WorkflowRun(
            id: id,
            name: workflow,
            displayTitle: message,
            headBranch: branch,
            headSHA: sha,
            status: status,
            conclusion: conclusion,
            createdAt: startedAt,
            runStartedAt: startedAt,
            updatedAt: updatedAt,
            event: "push",
            htmlURL: URL(string: "https://github.com/alexpricedev/atlas/actions/runs/\(id)")!,
            headCommit: WorkflowRun.HeadCommit(id: sha, message: message)
        )
    }

    static func pullRequest(
        repo: RepoID = atlas.id,
        number: Int = 12,
        title: String = "Add the cross-repo view",
        author: String = "alexpricedev",
        createdAt: Date = date("2026-10-20T09:00:00Z"),
        isDraft: Bool = false,
        headSHA: String = "9999999999999999999999999999999999999999"
    ) -> PullRequestRow {
        PullRequestRow(
            repo: repo,
            number: number,
            title: title,
            author: author,
            createdAt: createdAt,
            isDraft: isDraft,
            headSHA: headSHA,
            url: URL(string: "https://github.com/\(repo.slug)/pull/\(number)")!
        )
    }

    static func issue(
        repo: RepoID = atlas.id,
        number: Int = 33,
        title: String = "Deploy workflow fails on tag builds",
        labels: [String] = ["bug", "ci"],
        createdAt: Date = date("2026-10-25T09:00:00Z")
    ) -> IssueRow {
        IssueRow(
            repo: repo,
            number: number,
            title: title,
            labels: labels,
            createdAt: createdAt,
            url: URL(string: "https://github.com/\(repo.slug)/issues/\(number)")!
        )
    }
}
