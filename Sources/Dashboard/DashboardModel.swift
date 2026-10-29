import Foundation
import Observation

/// All of the dashboard's state and the polling loop that keeps it current.
/// Network access is entirely behind `GitHubClientProtocol`, so tests drive it
/// with fixture data and a fake clock.
@MainActor
@Observable
final class DashboardModel {
    private let client: any GitHubClientProtocol
    let settings: AppSettings
    private let clock: any Clocking
    let cadence: PollCadence
    let governor: RateLimitGovernor

    /// How many rows the Actions and pull request columns show.
    static let feedLimit = 25

    // Raw data, keyed so that every section is a pure derivation of it.
    private(set) var reposByOwner: [String: [Repo]] = [:]
    private(set) var runsByRepo: [RepoID: [WorkflowRun]] = [:]
    private(set) var pullRequestsByOwner: [String: [PullRequestRow]] = [:]
    private(set) var issuesByOwner: [String: [IssueRow]] = [:]
    private(set) var ciByRepo: [RepoID: [String: CIRollup]] = [:]

    // Health, shown in place rather than as alerts.
    private(set) var ownerHealth: [String: OwnerHealth] = [:]
    private(set) var repoErrors: [RepoID: String] = [:]
    private(set) var rateLimits: [String: RateLimitInfo] = [:]

    // Status.
    private(set) var lastRefreshed: Date?
    private(set) var isRefreshing = false
    private(set) var isPolling = false

    // Toolbar filters. These only affect what is shown, not what is polled.
    var ownerFilter: String?
    var repoFilter: String = ""

    private var planner = PollPlanner()
    private var pollTask: Task<Void, Never>?
    private var errorsThisPass: Set<String> = []

    init(
        client: any GitHubClientProtocol,
        settings: AppSettings,
        clock: any Clocking = SystemClock(),
        cadence: PollCadence = PollCadence(),
        governor: RateLimitGovernor = RateLimitGovernor()
    ) {
        self.client = client
        self.settings = settings
        self.clock = clock
        self.cadence = cadence
        self.governor = governor
    }

    // MARK: - Derived state

    var owners: [Owner] {
        settings.owners
    }

    var ownerBanners: [OwnerBanner] {
        settings.owners.compactMap { owner in
            guard let health = ownerHealth[owner.login] else { return nil }
            guard let message = health.tokenError ?? health.message else { return nil }
            return OwnerBanner(owner: owner, message: message)
        }
    }

    var knownRepos: [Repo] {
        reposByOwner.values.flatMap(\.self).sorted {
            $0.id.slug.localizedStandardCompare($1.id.slug) == .orderedAscending
        }
    }

    /// A repo the app is actively watching: still listed for its owner (so
    /// archived and forked repos are out), not hidden, and passing the filters.
    func isRepoVisible(_ repo: RepoID) -> Bool {
        guard !settings.hiddenRepos.contains(repo.slug) else { return false }
        let listed = reposByOwner[repo.owner]?.contains { $0.id == repo } ?? false
        guard listed else { return false }
        if let ownerFilter, ownerFilter.caseInsensitiveCompare(repo.owner) != .orderedSame {
            return false
        }
        let text = repoFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !repo.name.localizedCaseInsensitiveContains(text) {
            return false
        }
        return true
    }

    /// The Actions feed: anything still running always appears, then the
    /// newest finished runs fill the remainder, capped at 25. Newest first.
    var actionRows: [ActionRow] {
        let limit = Self.feedLimit
        let visible = runsByRepo.flatMap { repo, runs -> [(RepoID, WorkflowRun)] in
            guard isRepoVisible(repo) else { return [] }
            return runs.map { (repo, $0) }
        }
        let active = visible.filter(\.1.isActive)
        let finished = visible
            .filter { !$0.1.isActive }
            .sorted { $0.1.startedAt > $1.1.startedAt }

        var entries = active
        entries.append(contentsOf: finished.prefix(max(0, limit - active.count)))
        return entries
            .sorted { $0.1.startedAt > $1.1.startedAt }
            .prefix(limit)
            .map { ActionRow(run: $1, repo: $0) }
    }

    /// Every open pull request that passes the filters, newest first.
    var pullRequestRows: [PullRequestRow] {
        pullRequestsByOwner.values
            .flatMap(\.self)
            .filter { isRepoVisible($0.repo) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// The overview shows the newest pull requests, same cap as the feed.
    var latestPullRequests: [PullRequestRow] {
        Array(pullRequestRows.prefix(Self.feedLimit))
    }

    var issueRows: [IssueRow] {
        issuesByOwner.values
            .flatMap(\.self)
            .filter { isRepoVisible($0.repo) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func ciStatus(for pullRequest: PullRequestRow) -> CIRollup {
        ciByRepo[pullRequest.repo]?[pullRequest.headSHA] ?? .none
    }

    func repoWarning(for repo: RepoID) -> String? {
        repoErrors[repo]
    }

    // MARK: - Polling lifecycle

    func startPolling() {
        guard pollTask == nil else { return }
        isPolling = true
        pollTask = Task { [weak self] in
            await self?.pollLoop()
        }
    }

    func pausePolling() {
        pollTask?.cancel()
        pollTask = nil
        isPolling = false
    }

    /// Refresh immediately after the window reopens or the Mac wakes, then
    /// carry on with the normal cadence.
    func resumePolling() {
        guard pollTask == nil else { return }
        planner.markAllDue(at: clock.now)
        startPolling()
    }

    private func pollLoop() async {
        while !Task.isCancelled {
            await refreshDue()
            if Task.isCancelled { return }
            let now = clock.now
            let wake = planner.nextWake(after: now) ?? now.addingTimeInterval(30)
            let delay = min(max(wake.timeIntervalSince(now), 1), 30)
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
        }
    }

    /// ⌘R, and the first load. Forces every resource to be fetched again.
    func refreshAll() async {
        planner.markAllDue(at: clock.now)
        await refreshDue(force: true)
    }

    /// Called when owners or hidden repositories change. Drops state for owners
    /// that are gone, re-reads everything else.
    func settingsDidChange() async {
        let liveOwners = settings.owners
        let liveLogins = Set(liveOwners.map(\.login))
        for login in ownerHealth.keys where !liveLogins.contains(login) {
            ownerHealth[login] = nil
            rateLimits[login] = nil
            reposByOwner[login] = nil
            pullRequestsByOwner[login] = nil
            issuesByOwner[login] = nil
        }

        // A replaced token deserves a clean slate.
        for owner in liveOwners {
            clearHealth(owner: owner.login)
        }

        let liveRepos = Set(pollableRepos().map(\.id))
        var keys: Set<PollKey> = []
        for owner in liveOwners {
            keys.insert(.repos(owner.login))
            keys.insert(.search(owner.login))
        }
        for repo in liveRepos {
            keys.insert(.runs(repo))
        }
        for pullRequest in pullRequestsByOwner.values.joined() where liveRepos.contains(pullRequest.repo) {
            keys.insert(.ci(pullRequest.repo, pullRequest.headSHA))
        }
        planner.retain(keys)
        planner.markAllDue(at: clock.now)
        await refreshDue(force: true)
    }

    // MARK: - Refresh

    private func refreshDue(force: Bool = false) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorsThisPass = []
        defer {
            isRefreshing = false
            lastRefreshed = clock.now
        }

        let ownerList = settings.owners
        for owner in ownerList {
            if let info = await client.rateLimit(for: owner.login) {
                rateLimits[owner.login] = info
            }
        }
        if Task.isCancelled { return }

        let now = clock.now

        // Repositories, per owner.
        for owner in ownerList {
            let key = PollKey.repos(owner.login)
            if force || reposByOwner[owner.login] == nil || planner.isDue(key, at: now) {
                await loadRepos(owner: owner, now: now)
                if Task.isCancelled { return }
            }
        }

        // Workflow runs, for every visible repository that is due.
        let dueRepos = pollableRepos().filter { repo in
            force
                || planner.isDue(.runs(repo.id), at: now)
                || runsByRepo[repo.id] == nil
        }
        let results = await fetchRepoData(dueRepos)
        apply(results, now: now)
        if Task.isCancelled { return }

        // Pull requests and issues, per owner.
        for owner in ownerList {
            if force || pullRequestsByOwner[owner.login] == nil || planner.isDue(.search(owner.login), at: now) {
                await loadSearch(owner: owner, now: now)
                if Task.isCancelled { return }
            }
        }

        // CI status of pull request heads.
        await refreshCI(force: force, now: clock.now)

        // Only clear a token error when every call for that owner worked.
        for owner in ownerList where !errorsThisPass.contains(owner.login) {
            clearHealth(owner: owner.login)
        }
    }

    private func loadRepos(owner: Owner, now: Date) async {
        do {
            let repos = try await client.listRepos(owner: owner)
            reposByOwner[owner.login] = repos
            pruneState(for: owner.login, keeping: Set(repos.map(\.id)))
            schedule(.repos(owner.login), base: cadence.repoListInterval, owner: owner.login, now: now)
        } catch let error as GitHubError {
            handle(error: error, owner: owner.login)
            schedule(.repos(owner.login), base: cadence.repoListInterval, owner: owner.login, now: now)
        } catch {
            handle(error: .transport(error.localizedDescription), owner: owner.login)
        }
    }

    private func fetchRepoData(_ repos: [Repo]) async -> [RepoFetchResult] {
        guard !repos.isEmpty else { return [] }
        let client = client
        let limit = 4
        var results: [RepoFetchResult] = []
        await withTaskGroup(of: RepoFetchResult.self) { group in
            var iterator = repos.makeIterator()
            for _ in 0 ..< limit {
                guard let repo = iterator.next() else { break }
                group.addTask { await RepoFetchResult.fetch(repo: repo, client: client) }
            }
            while let result = await group.next() {
                results.append(result)
                guard let repo = iterator.next() else { continue }
                group.addTask { await RepoFetchResult.fetch(repo: repo, client: client) }
            }
        }
        return results
    }

    private func apply(_ results: [RepoFetchResult], now: Date) {
        for result in results {
            let repo = result.repo
            var hasRunningRun = runsByRepo[repo.id]?.contains(where: \.isActive) ?? false

            switch result.runs {
            case let .success(runs):
                runsByRepo[repo.id] = runs
                hasRunningRun = runs.contains(where: \.isActive)
                repoErrors[repo.id] = nil
            case let .failure(error):
                handle(error: error, owner: repo.owner)
                if error != .cancelled {
                    repoErrors[repo.id] = error.shortMessage
                }
            }

            let interval = cadence.repoInterval(
                hasRunningRun: hasRunningRun,
                lastPush: repo.pushedAt,
                now: now
            )
            schedule(.runs(repo.id), base: interval, owner: repo.owner, now: now)
        }
    }

    private func loadSearch(owner: Owner, now: Date) async {
        async let issuesResult = capture {
            try await client.openIssues(owner: owner)
        }

        // Pull requests come from each repository, because only that endpoint
        // carries the head SHA the CI status needs.
        let repos = reposByOwner[owner.login] ?? []
        let pullRequestResults = await fetchPullRequests(repos, owner: owner.login)

        var pullRequests: [PullRequestRow] = []
        var failures: [RepoID: GitHubError] = [:]
        for (repo, result) in pullRequestResults {
            switch result {
            case let .success(rows):
                pullRequests.append(contentsOf: rows)
            case let .failure(error):
                guard error != .cancelled else { continue }
                failures[repo] = error
            }
        }

        // Keep the last good pull requests for repositories that failed.
        if !failures.isEmpty {
            let previous = pullRequestsByOwner[owner.login] ?? []
            pullRequests.append(contentsOf: previous.filter { failures.keys.contains($0.repo) })
            for (repo, error) in failures {
                repoErrors[repo] = error.shortMessage
                handle(error: error, owner: owner.login)
            }
        }
        pullRequestsByOwner[owner.login] = pullRequests

        if case let .failure(error) = await issuesResult {
            handle(error: error, owner: owner.login)
        } else if case let .success(rows) = await issuesResult {
            issuesByOwner[owner.login] = rows
        }

        schedule(.search(owner.login), base: cadence.searchInterval, owner: owner.login, now: now)
    }

    private func fetchPullRequests(
        _ repos: [Repo],
        owner: String
    ) async -> [(RepoID, Result<[PullRequestRow], GitHubError>)] {
        guard !repos.isEmpty else { return [] }
        let client = client
        let limit = 4
        var results: [(RepoID, Result<[PullRequestRow], GitHubError>)] = []
        await withTaskGroup(of: (RepoID, Result<[PullRequestRow], GitHubError>).self) { group in
            var iterator = repos.makeIterator()
            for _ in 0 ..< limit {
                guard let repo = iterator.next() else { break }
                group.addTask {
                    let result = await capture {
                        try await client.openPullRequests(repo: repo.id, owner: owner)
                    }
                    return (repo.id, result)
                }
            }
            while let result = await group.next() {
                results.append(result)
                guard let repo = iterator.next() else { continue }
                group.addTask {
                    let result = await capture {
                        try await client.openPullRequests(repo: repo.id, owner: owner)
                    }
                    return (repo.id, result)
                }
            }
        }
        return results
    }

    private func refreshCI(force: Bool, now: Date) async {
        var shasByRepo: [RepoID: Set<String>] = [:]
        for pullRequest in pullRequestsByOwner.values.joined() {
            // Filters are presentational; CI should keep updating for hidden-by-filter repos.
            guard !settings.hiddenRepos.contains(pullRequest.repo.slug), !pullRequest.headSHA.isEmpty else { continue }
            shasByRepo[pullRequest.repo, default: []].insert(pullRequest.headSHA)
        }

        for (repo, shas) in shasByRepo {
            for sha in shas {
                let key = PollKey.ci(repo, sha)
                if !force, !planner.isDue(key, at: now) { continue }
                do {
                    let rollup = try await client.ciRollup(repo: repo, owner: repo.owner, headSHA: sha)
                    var statuses = ciByRepo[repo] ?? [:]
                    statuses[sha] = rollup
                    ciByRepo[repo] = statuses
                    // Keep watching while checks are running; otherwise check
                    // back in an hour in case the commit is run again.
                    let base: TimeInterval = rollup == .pending ? cadence.searchInterval : 3600
                    schedule(.ci(repo, sha), base: base, owner: repo.owner, now: now)
                } catch let error as GitHubError {
                    if error == .cancelled { continue }
                    var statuses = ciByRepo[repo] ?? [:]
                    statuses[sha] = statuses[sha] ?? CIRollup.none
                    ciByRepo[repo] = statuses
                } catch {
                    continue
                }
            }
        }
    }

    // MARK: - Helpers

    /// Forgets runs, pull requests, issues, CI status and errors for repos that
    /// are no longer listed, e.g. because they were archived.
    private func pruneState(for owner: String, keeping ids: Set<RepoID>) {
        runsByRepo = runsByRepo.filter { ids.contains($0.key) }
        ciByRepo = ciByRepo.filter { ids.contains($0.key) }
        repoErrors = repoErrors.filter { ids.contains($0.key) }
        pullRequestsByOwner[owner] = (pullRequestsByOwner[owner] ?? []).filter { ids.contains($0.repo) }
        issuesByOwner[owner] = (issuesByOwner[owner] ?? []).filter { ids.contains($0.repo) }
        prunePlanner()
    }

    /// Stops polling repos the app no longer watches.
    private func prunePlanner() {
        let liveOwners = Set(settings.owners.map(\.login))
        let liveRepos = Set(reposByOwner.values.flatMap { $0.map(\.id) })
        let keys = planner.keys.filter { key in
            guard liveOwners.contains(key.owner) else { return false }
            guard let repo = key.repo else { return true }
            return liveRepos.contains(repo)
        }
        planner.retain(keys)
    }

    private func pollableRepos() -> [Repo] {
        reposByOwner.values
            .flatMap(\.self)
            .filter { !settings.hiddenRepos.contains($0.id.slug) }
    }

    private func schedule(_ key: PollKey, base: TimeInterval, owner: String, now: Date) {
        let interval = governor.interval(base: base, info: rateLimits[owner], now: now)
        planner.schedule(key, in: interval, from: now)
    }

    private func handle(error: GitHubError, owner: String) {
        guard error != .cancelled else { return }
        errorsThisPass.insert(owner)

        var health = ownerHealth[owner] ?? OwnerHealth()
        switch error {
        case let .unauthorized(message), let .forbidden(message):
            health.tokenError = message
        case let .rateLimited(reset):
            if let reset {
                health.message = "Rate limited until \(reset.formatted(date: .omitted, time: .shortened))."
            } else {
                health.message = "Rate limited."
            }
        default:
            health.message = error.userMessage
        }
        ownerHealth[owner] = health
    }

    private func clearHealth(owner: String) {
        guard var health = ownerHealth[owner] else { return }
        health.tokenError = nil
        health.message = nil
        ownerHealth[owner] = health
    }
}
