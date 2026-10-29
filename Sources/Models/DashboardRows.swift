import Foundation

/// The icon-worthy state of a workflow run.
enum ActionState: String, Hashable {
    case success
    case failure
    case inProgress
    case neutral

    static func from(status: RunStatus, conclusion: RunConclusion?) -> ActionState {
        if status.isActive { return .inProgress }
        guard let conclusion else { return .neutral }
        if conclusion.isFailure { return .failure }
        switch conclusion {
        case .success: return .success
        default: return .neutral
        }
    }
}

/// One workflow run in the Actions feed.
struct ActionRow: Identifiable, Hashable {
    let id: Int64
    let repo: RepoID
    let workflowName: String
    let state: ActionState
    let message: String
    let shortSHA: String
    let ref: String
    let isProductionRelease: Bool
    let startedAt: Date
    let finishedAt: Date?
    let isRunning: Bool
    let isQueued: Bool
    let url: URL

    init(run: WorkflowRun, repo: RepoID) {
        id = run.id
        self.repo = repo
        workflowName = run.workflowName
        state = ActionState.from(status: run.runStatus, conclusion: run.runConclusion)
        message = run.commitTitle ?? "No commit message"
        shortSHA = run.shortSHA
        ref = run.ref
        isProductionRelease = run.isProductionRelease
        startedAt = run.startedAt
        finishedAt = run.isActive ? nil : run.updatedAt
        isRunning = run.isActive
        isQueued = run.runStatus == .queued
        url = run.htmlURL
    }

    func duration(now: Date) -> TimeInterval {
        let end = finishedAt ?? now
        return max(0, end.timeIntervalSince(startedAt))
    }
}

struct PullRequestRow: Identifiable, Hashable {
    let id: String
    let repo: RepoID
    let number: Int
    let title: String
    let author: String
    let createdAt: Date
    let isDraft: Bool
    let headSHA: String
    let url: URL

    init(
        repo: RepoID,
        number: Int,
        title: String,
        author: String,
        createdAt: Date,
        isDraft: Bool,
        headSHA: String,
        url: URL
    ) {
        id = "\(repo.slug)#\(number)"
        self.repo = repo
        self.number = number
        self.title = title
        self.author = author
        self.createdAt = createdAt
        self.isDraft = isDraft
        self.headSHA = headSHA
        self.url = url
    }
}

struct IssueRow: Identifiable, Hashable {
    let id: String
    let repo: RepoID
    let number: Int
    let title: String
    let labels: [String]
    let createdAt: Date
    let url: URL

    init(
        repo: RepoID,
        number: Int,
        title: String,
        labels: [String],
        createdAt: Date,
        url: URL
    ) {
        id = "\(repo.slug)#\(number)"
        self.repo = repo
        self.number = number
        self.title = title
        self.labels = labels
        self.createdAt = createdAt
        self.url = url
    }
}

struct OwnerHealth: Hashable {
    var tokenError: String?
    var message: String?

    var hasProblem: Bool {
        tokenError != nil || message != nil
    }
}

struct OwnerBanner: Identifiable, Hashable {
    let owner: Owner
    let message: String

    var id: String {
        owner.login
    }
}
