import Foundation

struct RepoFetchResult {
    let repo: Repo
    let runs: Result<[WorkflowRun], GitHubError>

    static func fetch(repo: Repo, client: any GitHubClientProtocol) async -> RepoFetchResult {
        await RepoFetchResult(
            repo: repo,
            runs: capture { try await client.recentRuns(repo: repo.id, owner: repo.owner) }
        )
    }
}

/// Turns a throwing client call into a `Result` the caller can merge without
/// caring about error types.
func capture<T: Sendable>(_ operation: @Sendable () async throws -> T) async -> Result<T, GitHubError> {
    do {
        return try await .success(operation())
    } catch let error as GitHubError {
        return .failure(error)
    } catch is CancellationError {
        return .failure(.cancelled)
    } catch {
        return .failure(.transport(error.localizedDescription))
    }
}
