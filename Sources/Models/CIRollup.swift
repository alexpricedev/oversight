import Foundation

/// The combined CI state of the runs for a pull request's head commit.
enum CIRollup: String, Hashable, CaseIterable {
    case none
    case pending
    case success
    case failure
    case neutral

    var label: String {
        switch self {
        case .none: "No checks"
        case .pending: "Pending"
        case .success: "Passing"
        case .failure: "Failing"
        case .neutral: "Neutral"
        }
    }

    /// Any failure wins. Otherwise any unfinished run means pending. Then any
    /// success means success, and anything else (only skipped or cancelled
    /// runs) is neutral.
    static func from(_ runs: [WorkflowRun]) -> CIRollup {
        guard !runs.isEmpty else { return .none }
        if runs.contains(where: { $0.runConclusion?.isFailure == true }) { return .failure }
        if runs.contains(where: \.isActive) { return .pending }
        if runs.contains(where: { $0.runConclusion == .success }) { return .success }
        return .neutral
    }
}
