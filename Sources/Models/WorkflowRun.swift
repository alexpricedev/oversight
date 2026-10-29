import Foundation

enum RunStatus: String, Hashable {
    case queued
    case inProgress = "in_progress"
    case requested
    case waiting
    case pending
    case completed
    case unknown

    init(raw: String?) {
        guard let raw, let value = RunStatus(rawValue: raw) else {
            self = .unknown
            return
        }
        self = value
    }

    /// A run in any of these states has not finished yet.
    var isActive: Bool {
        switch self {
        case .queued, .inProgress, .requested, .waiting, .pending: true
        case .completed, .unknown: false
        }
    }
}

enum RunConclusion: String, Hashable {
    case success
    case failure
    case cancelled
    case skipped
    case neutral
    case timedOut = "timed_out"
    case actionRequired = "action_required"
    case stale
    case startupFailure = "startup_failure"
    case unknown

    init(raw: String?) {
        guard let raw, let value = RunConclusion(rawValue: raw) else {
            self = .unknown
            return
        }
        self = value
    }

    var isFailure: Bool {
        switch self {
        case .failure, .timedOut, .startupFailure: true
        default: false
        }
    }
}

struct WorkflowRun: Decodable, Hashable, Identifiable {
    struct HeadCommit: Decodable, Hashable {
        let id: String?
        let message: String?

        enum CodingKeys: String, CodingKey {
            case id, message
        }
    }

    let id: Int64
    let name: String?
    let displayTitle: String?
    let headBranch: String?
    let headSHA: String
    let status: String
    let conclusion: String?
    let createdAt: Date
    let runStartedAt: Date?
    let updatedAt: Date
    let event: String?
    let htmlURL: URL
    let headCommit: HeadCommit?

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, event
        case displayTitle = "display_title"
        case headBranch = "head_branch"
        case headSHA = "head_sha"
        case createdAt = "created_at"
        case runStartedAt = "run_started_at"
        case updatedAt = "updated_at"
        case htmlURL = "html_url"
        case headCommit = "head_commit"
    }

    var runStatus: RunStatus {
        RunStatus(raw: status)
    }

    var runConclusion: RunConclusion? {
        RunConclusion(raw: conclusion)
    }

    var isActive: Bool {
        runStatus.isActive
    }

    var startedAt: Date {
        runStartedAt ?? createdAt
    }

    var workflowName: String {
        name ?? "Workflow"
    }

    var shortSHA: String {
        String(headSHA.prefix(7))
    }

    /// The first line of the commit message, used for deploy rows.
    var commitTitle: String? {
        if let message = headCommit?.message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            return message.split(separator: "\n", maxSplits: 1).first.map(String.init)?
                .trimmingCharacters(in: .whitespaces)
        }
        if let title = displayTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return nil
    }

    var ref: String {
        headBranch ?? "—"
    }

    /// A `v*` tag run is treated as a production release.
    var isProductionRelease: Bool {
        guard ref.count > 1, ref.first == "v" else { return false }
        return ref.dropFirst().first?.isNumber ?? false
    }
}
