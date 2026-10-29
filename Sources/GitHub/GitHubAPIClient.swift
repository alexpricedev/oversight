import Foundation

/// Talks to the GitHub REST API. One instance is shared by the app; each call
/// names the account whose token pays for it. Organization repositories are
/// read with the token of the account that belongs to the organization.
actor GitHubAPIClient: GitHubClientProtocol {
    private let transport: any HTTPTransport
    private let cache: ETagCache
    private let ledger: RateLimitLedger
    private let tokenProvider: @Sendable (String) -> String?
    private let baseURL: URL
    private let clock: any Clocking
    /// Normally 100. Tests use a smaller page so pagination is cheap to cover.
    private let pageSize: Int

    init(
        transport: any HTTPTransport = URLSessionTransport(),
        tokenProvider: @escaping @Sendable (String) -> String?,
        baseURL: URL = URL(string: "https://api.github.com")!,
        clock: any Clocking = SystemClock(),
        pageSize: Int = 100
    ) {
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.baseURL = baseURL
        self.clock = clock
        self.pageSize = pageSize
        cache = ETagCache()
        ledger = RateLimitLedger()
    }

    // MARK: - GitHubClientProtocol

    func listRepos(account: Owner) async throws -> [Repo] {
        let token = try token(for: account.login)
        // An organization-owned token cannot use /user/repos: it only has
        // access to the organization, so ask for that organization's repos.
        let isOrganization = account.kind == .organization
        var repos: [Repo] = []
        var page = 1
        while page <= 20 {
            let url = try makeURL(
                path: isOrganization ? "/orgs/\(account.login)/repos" : "/user/repos",
                query: isOrganization
                    ? [
                        URLQueryItem(name: "per_page", value: String(pageSize)),
                        URLQueryItem(name: "page", value: String(page)),
                        URLQueryItem(name: "type", value: "all"),
                    ]
                    : [
                        URLQueryItem(name: "per_page", value: String(pageSize)),
                        URLQueryItem(name: "page", value: String(page)),
                        URLQueryItem(name: "sort", value: "pushed"),
                        URLQueryItem(name: "direction", value: "desc"),
                        // Repositories you own plus the ones your organizations
                        // own. Collaborator-only repos belong to somebody else.
                        URLQueryItem(name: "affiliation", value: "owner,organization_member"),
                    ]
            )
            let payloads: [RepoPayload] = try await fetchValue(url: url, token: token, tokenOwner: account.login)
            repos.append(contentsOf: payloads.compactMap { $0.toRepo() })
            if payloads.count < pageSize { break }
            page += 1
        }
        return repos
            .filter { !$0.isArchived && !$0.isFork }
            .sorted { $0.id.slug.localizedStandardCompare($1.id.slug) == .orderedAscending }
    }

    func recentRuns(repo: RepoID, account: String) async throws -> [WorkflowRun] {
        let token = try token(for: account)
        let url = try makeURL(
            path: "/repos/\(repo.owner)/\(repo.name)/actions/runs",
            query: [URLQueryItem(name: "per_page", value: "20")]
        )
        let response: WorkflowRunsResponse = try await fetchValue(url: url, token: token, tokenOwner: account)
        return response.workflowRuns
    }

    func openPullRequests(repo: RepoID, account: String) async throws -> [PullRequestRow] {
        let token = try token(for: account)
        var rows: [PullRequestRow] = []
        var page = 1
        while page <= 10 {
            let url = try makeURL(
                path: "/repos/\(repo.owner)/\(repo.name)/pulls",
                query: [
                    URLQueryItem(name: "state", value: "open"),
                    URLQueryItem(name: "per_page", value: String(pageSize)),
                    URLQueryItem(name: "page", value: String(page)),
                ]
            )
            let payloads: [PullPayload] = try await fetchValue(url: url, token: token, tokenOwner: account)
            rows.append(contentsOf: payloads.map { $0.toRow(repo: repo) })
            if payloads.count < pageSize { break }
            page += 1
        }
        return rows
    }

    func openIssues(owner: Owner, account: String) async throws -> [IssueRow] {
        let token = try token(for: account)
        let query = "is:open is:issue \(owner.kind.searchQualifier):\(owner.login)"
        var rows: [IssueRow] = []
        var page = 1
        while page <= 10 {
            let url = try makeURL(
                path: "/search/issues",
                query: [
                    URLQueryItem(name: "q", value: query),
                    URLQueryItem(name: "per_page", value: String(pageSize)),
                    URLQueryItem(name: "page", value: String(page)),
                ]
            )
            let response: SearchResponse = try await fetchValue(url: url, token: token, tokenOwner: account)
            // Search already filters to issues, but drop anything that is a
            // pull request so the two sections can never overlap.
            rows.append(contentsOf: response.items.compactMap { $0.toIssueRow() })
            if response.items.count < pageSize { break }
            page += 1
        }
        return rows.filter { $0.repo.owner.caseInsensitiveCompare(owner.login) == .orderedSame }
    }

    func ciRollup(repo: RepoID, account: String, headSHA: String) async throws -> CIRollup {
        guard !headSHA.isEmpty else { return .none }
        let token = try token(for: account)
        let url = try makeURL(
            path: "/repos/\(repo.owner)/\(repo.name)/actions/runs",
            query: [
                URLQueryItem(name: "head_sha", value: headSHA),
                URLQueryItem(name: "per_page", value: "20"),
            ]
        )
        let response: WorkflowRunsResponse = try await fetchValue(url: url, token: token, tokenOwner: account)
        return CIRollup.from(response.workflowRuns)
    }

    func verifyOwner(login: String, token: String) async throws -> Owner {
        let trimmed = login.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(" ") else {
            throw GitHubError.forbidden("Enter a GitHub user or organization name, with no slashes or spaces.")
        }

        // The token must be valid. A token owned by an organization can only
        // touch that organization, and /user may refuse it; that is fine as
        // long as the repository probe below succeeds.
        do {
            let viewer: UserPayload = try await fetchValue(
                url: makeURL(path: "/user"),
                token: token,
                tokenOwner: trimmed
            )
            guard !viewer.login.isEmpty else {
                throw GitHubError.unauthorized("GitHub rejected this token.")
            }
        } catch let error as GitHubError {
            if case .unauthorized = error { throw error }
        }

        // The owner must exist, and its kind decides the search qualifier.
        let ownerPayload: UserPayload
        do {
            ownerPayload = try await fetchValue(
                url: makeURL(path: "/users/\(trimmed)"),
                token: token,
                tokenOwner: trimmed
            )
        } catch GitHubError.notFound {
            throw GitHubError.forbidden("There's no GitHub user or organization named \(trimmed).")
        }
        let kind: OwnerKind = ownerPayload.type.caseInsensitiveCompare("Organization") == .orderedSame
            ? .organization
            : .user

        // The token must be able to list this owner's repositories. That is
        // what proves it is scoped to the right resource owner.
        let repos: [RepoPayload]
        do {
            repos = try await fetchValue(
                url: makeURL(
                    path: kind == .organization ? "/orgs/\(trimmed)/repos" : "/user/repos",
                    query: [URLQueryItem(name: "per_page", value: "100")]
                ),
                token: token,
                tokenOwner: trimmed
            )
        } catch let error as GitHubError {
            switch error {
            case .notFound, .forbidden:
                throw GitHubError.forbidden(
                    "This token can't see any of \(trimmed)'s repositories. Check that the token's resource owner is \(trimmed), and that its repository access covers them."
                )
            default:
                throw error
            }
        }
        guard !repos.isEmpty else {
            throw GitHubError.forbidden(
                "This token can't see any of \(trimmed)'s repositories. Check that the token's resource owner is \(trimmed), and that its repository access covers them."
            )
        }

        return Owner(login: trimmed, kind: kind)
    }

    func rateLimit(for account: String) async -> RateLimitInfo? {
        await ledger.info(for: account)
    }

    // MARK: - Requests

    private func token(for account: String) throws -> String {
        guard let token = tokenProvider(account), !token.isEmpty else {
            throw GitHubError.unauthorized("No token stored for \(account). Add one in Settings.")
        }
        return token
    }

    private func fetchValue<T: Decodable & Sendable>(
        url: URL,
        token: String,
        tokenOwner: String
    ) async throws -> T {
        let data = try await fetch(url: url, token: token, tokenOwner: tokenOwner)
        do {
            return try GitHubJSON.decode(T.self, from: data)
        } catch {
            throw GitHubError.decoding("\(T.self): \(error.localizedDescription)")
        }
    }

    private func fetch(url: URL, token: String, tokenOwner: String) async throws -> Data {
        let key = "\(tokenOwner)|\(url.absoluteString)"
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Oversight/0.1", forHTTPHeaderField: "User-Agent")

        let cached = await cache.entry(for: key)
        if let cached {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch let error as URLError where error.code == .cancelled {
            throw GitHubError.cancelled
        } catch is CancellationError {
            throw GitHubError.cancelled
        } catch {
            throw GitHubError.transport(error.localizedDescription)
        }

        if let info = RateLimitInfo(headers: response.allHeaderFields, observedAt: clock.now) {
            await ledger.record(info, for: tokenOwner)
        }

        switch response.statusCode {
        case 304:
            guard let cached else {
                throw GitHubError.server(status: 304, message: "Not modified, but no cached response to use.")
            }
            return cached.data

        case 200 ..< 300:
            if let etag = response.value(forHTTPHeaderField: "ETag"), !etag.isEmpty {
                await cache.store(ETagCache.Entry(etag: etag, data: data), for: key)
            }
            return data

        case 401:
            throw GitHubError.unauthorized(Self.message(from: data) ?? "GitHub rejected this token.")

        case 403:
            let remaining = Self.intHeader("x-ratelimit-remaining", in: response)
            let body = Self.message(from: data)
            if remaining == 0 || (body?.lowercased().contains("rate limit") ?? false) {
                throw GitHubError.rateLimited(reset: Self.resetDate(from: response))
            }
            throw GitHubError.forbidden(
                body ?? "GitHub denied access. Check the token's permissions for this repository."
            )

        case 404:
            throw GitHubError.notFound

        default:
            throw GitHubError.server(
                status: response.statusCode,
                message: Self.message(from: data) ?? "Unexpected response."
            )
        }
    }

    private func makeURL(path: String, query: [URLQueryItem] = []) throws -> URL {
        let base = baseURL.absoluteString.hasSuffix("/") ? String(baseURL.absoluteString.dropLast()) : baseURL.absoluteString
        guard var components = URLComponents(string: base + path) else {
            throw GitHubError.transport("Couldn't build a GitHub URL for \(path).")
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw GitHubError.transport("Couldn't build a GitHub URL for \(path).")
        }
        return url
    }

    // MARK: - Helpers

    private static func message(from data: Data) -> String? {
        (try? JSONDecoder().decode(ErrorPayload.self, from: data))?.message
    }

    private static func intHeader(_ name: String, in response: HTTPURLResponse) -> Int? {
        response.value(forHTTPHeaderField: name).flatMap(Int.init)
    }

    private static func resetDate(from response: HTTPURLResponse) -> Date? {
        response.value(forHTTPHeaderField: "x-ratelimit-reset")
            .flatMap(TimeInterval.init)
            .map(Date.init(timeIntervalSince1970:))
    }
}
