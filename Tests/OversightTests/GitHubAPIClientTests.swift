import Foundation
@testable import Oversight
import Testing

@Suite("GitHub API client")
struct GitHubAPIClientTests {
    private let owner = Owner(login: "alexpricedev", kind: .user)
    private let repo = Sample.atlas.id

    private func makeClient(_ transport: StubTransport, pageSize: Int = 100) -> GitHubAPIClient {
        GitHubAPIClient(
            transport: transport,
            tokenProvider: { _ in "test-token" },
            baseURL: URL(string: "https://api.github.com")!,
            clock: TestClock(),
            pageSize: pageSize
        )
    }

    @Test("The repo list paginates, keeps organization repos, and drops archived repos and forks")
    func listsPagedReposAndFilters() async throws {
        let transport = StubTransport { request in
            let page = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "page" }?
                .value
            switch page {
            case "1": return try .json(Fixtures.data("repos_page_1"))
            case "2": return try .json(Fixtures.data("repos_page_2"))
            default: return .json(Data("[]".utf8))
            }
        }
        let client = makeClient(transport, pageSize: 3)

        let repos = try await client.listRepos(account: owner)

        #expect(repos.map(\.id.slug) == ["alexpricedev/atlas", "someone-else/someone-atlas"])
        let requests = await transport.recordedRequests()
        #expect(requests.count == 2)
        // Collaborator-only repositories belong to somebody else, so the
        // request asks for the account's own repos and its organizations'.
        let firstURL = requests.first.flatMap(\.url)
        let components = firstURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let affiliation = components?
            .queryItems?
            .first { $0.name == "affiliation" }?
            .value
        #expect(affiliation == "owner,organization_member")
    }

    @Test("A missing token fails before any request is made")
    func missingToken() async {
        let transport = StubTransport { _ in .init() }
        let client = GitHubAPIClient(transport: transport, tokenProvider: { _ in nil })

        do {
            _ = try await client.listRepos(account: owner)
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case let .unauthorized(message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(message.contains("No token stored"))
            let requests = await transport.recordedRequests()
            #expect(requests.isEmpty)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A 401 becomes an unauthorized error carrying GitHub's message")
    func unauthorized() async {
        let transport = StubTransport { _ in
            .error("Bad credentials", status: 401)
        }
        let client = makeClient(transport)

        do {
            _ = try await client.listRepos(account: owner)
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case let .unauthorized(message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(message == "Bad credentials")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Open pull requests come from the repo endpoint, with a head SHA and draft flag")
    func mapsPullRequests() async throws {
        let transport = StubTransport { _ in
            try .json(Fixtures.data("pulls"))
        }
        let client = makeClient(transport)
        let repo = RepoID(owner: "alexpricedev", name: "atlas")

        let rows = try await client.openPullRequests(repo: repo, account: owner.login)

        #expect(rows.count == 2)
        #expect(rows.map(\.number) == [91, 73])
        let draft = try #require(rows.first { $0.number == 73 })
        #expect(draft.isDraft)
        #expect(draft.repo == repo)
        #expect(draft.headSHA == "ab1772c2222222222222222222222222222222222")
        #expect(rows.first { $0.number == 91 }?.author == "tycho-bot[bot]")
        #expect(rows.first { $0.number == 91 }?.isDraft == false)
        #expect(rows.first { $0.number == 91 }?.labels == ["fettle"])

        let requests = await transport.recordedRequests()
        let request = try #require(requests.first)
        #expect(request.url?.path == "/repos/alexpricedev/atlas/pulls")
        let query = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "state" }?
            .value
        #expect(query == "open")
    }

    @Test("Issue search results drop anything that is a pull request")
    func mapsIssuesWithoutPullRequests() async throws {
        let transport = StubTransport { _ in
            try .json(Fixtures.data("search_issues"))
        }
        let client = makeClient(transport)

        let rows = try await client.openIssues(owner: owner, account: owner.login)

        #expect(rows.map(\.number).sorted() == [33, 34])
        #expect(rows.first { $0.number == 33 }?.labels == ["bug", "ci"])
    }

    @Test("Issue search follows pages so the count is not capped at one page")
    func paginatesIssues() async throws {
        let transport = StubTransport { request in
            let page = try URLComponents(url: #require(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "page" }?
                .value
            switch page {
            case "1": return try .json(Fixtures.data("search_issues_page_1"))
            case "2": return try .json(Fixtures.data("search_issues_page_2"))
            default: return .json(Data(#"{"total_count":2,"items":[]}"#.utf8))
            }
        }
        let client = makeClient(transport, pageSize: 1)

        let rows = try await client.openIssues(owner: owner, account: owner.login)

        #expect(rows.map(\.number).sorted() == [33, 34])
        let requests = await transport.recordedRequests()
        #expect(requests.count == 3)
    }

    @Test("For an organization owner the issue search uses the org qualifier")
    func organizationSearchQualifier() async throws {
        let transport = StubTransport { _ in
            .json(Data(#"{"total_count":0,"items":[]}"#.utf8))
        }
        let client = makeClient(transport)

        _ = try await client.openIssues(owner: Owner(login: "tycho-station", kind: .organization), account: "tycho-station")

        let requests = await transport.recordedRequests()
        let query = try URLComponents(url: #require(requests.first?.url), resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "q" }?
            .value
        #expect(query == "is:open is:issue org:tycho-station")
    }

    @Test("CI status comes from the workflow runs for the head SHA")
    func ciFromHeadSha() async throws {
        let transport = StubTransport { _ in
            try .json(Fixtures.data("ci_runs_failure"))
        }
        let client = makeClient(transport)

        let rollup = try await client.ciRollup(
            repo: repo,
            account: owner.login,
            headSHA: "9999999999999999999999999999999999999999"
        )

        #expect(rollup == .failure)
        let requests = await transport.recordedRequests()
        let sha = try URLComponents(url: #require(requests.first?.url), resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == "head_sha" }?
            .value
        #expect(sha == "9999999999999999999999999999999999999999")
    }

    @Test("A 304 keeps the previous data and the next request sends If-None-Match")
    func conditionalRequests() async throws {
        let transport = StubTransport { request in
            if request.value(forHTTPHeaderField: "If-None-Match") == "\"abc\"" {
                return .init(status: 304, headers: ["ETag": "\"abc\""], body: Data())
            }
            return try .init(
                status: 200,
                headers: ["ETag": "\"abc\""],
                body: Fixtures.data("workflow_runs")
            )
        }
        let client = makeClient(transport)

        let first = try await client.recentRuns(repo: repo, account: owner.login)
        let second = try await client.recentRuns(repo: repo, account: owner.login)

        #expect(first.count == 4)
        #expect(second.count == first.count)
        #expect(second.map(\.id) == first.map(\.id))

        let requests = await transport.recordedRequests()
        #expect(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "If-None-Match") == nil)
        #expect(requests[1].value(forHTTPHeaderField: "If-None-Match") == "\"abc\"")
    }

    @Test("Rate-limit headers are recorded per token, and search's bucket is ignored")
    func rateLimitHeaders() async throws {
        let core: [String: String] = [
            "x-ratelimit-limit": "5000",
            "x-ratelimit-remaining": "4990",
            "x-ratelimit-reset": "1800000000",
            "x-ratelimit-resource": "core",
        ]
        let search: [String: String] = [
            "x-ratelimit-limit": "30",
            "x-ratelimit-remaining": "12",
            "x-ratelimit-reset": "1800000000",
            "x-ratelimit-resource": "search",
        ]
        let transport = StubTransport { request in
            if request.url?.path == "/search/issues" {
                return .init(
                    status: 200,
                    headers: search,
                    body: Data(#"{"total_count":0,"items":[]}"#.utf8)
                )
            }
            return .init(status: 200, headers: core, body: Data("[]".utf8))
        }
        let client = makeClient(transport)

        _ = try await client.listRepos(account: owner)
        var info = await client.rateLimit(for: owner.login)
        #expect(info?.remaining == 4990)

        _ = try await client.openIssues(owner: owner, account: owner.login)
        info = await client.rateLimit(for: owner.login)
        #expect(info?.remaining == 4990)
        #expect(info?.limit == 5000)
    }

    @Test("Verifying an owner detects an organization and accepts a usable token")
    func verifyOrganization() async throws {
        let transport = StubTransport { request in
            switch request.url?.path {
            case "/user": try .json(Fixtures.data("user"))
            case "/users/tycho-station": try .json(Fixtures.data("org_user"))
            case "/orgs/tycho-station/repos": try .json(Fixtures.data("repos_page_1"))
            default: .error("Not Found", status: 404)
            }
        }
        let client = makeClient(transport)

        let verified = try await client.verifyOwner(login: "tycho-station", token: "a-token")
        #expect(verified == Owner(login: "tycho-station", kind: .organization))
    }

    @Test("An organization-owned token verifies even when /user refuses it")
    func verifyOrganizationOwnedToken() async throws {
        let transport = StubTransport { request in
            switch request.url?.path {
            case "/user": .error("Resource not accessible by personal access token", status: 403)
            case "/users/tycho-station": try .json(Fixtures.data("org_user"))
            case "/orgs/tycho-station/repos": try .json(Fixtures.data("repos_page_1"))
            default: .error("Not Found", status: 404)
            }
        }
        let client = makeClient(transport)

        let verified = try await client.verifyOwner(login: "tycho-station", token: "a-token")

        #expect(verified == Owner(login: "tycho-station", kind: .organization))
    }

    @Test("An organization account lists repositories through /orgs, not /user/repos")
    func listsOrganizationRepos() async throws {
        let transport = StubTransport { request in
            if request.url?.path == "/orgs/tycho-station/repos" {
                return try .json(Fixtures.data("repos_page_1"))
            }
            return .error("Not Found", status: 404)
        }
        let client = makeClient(transport)

        let repos = try await client.listRepos(
            account: Owner(login: "tycho-station", kind: .organization)
        )

        #expect(repos.map(\.id.slug) == ["alexpricedev/atlas"])
        let requests = await transport.recordedRequests()
        #expect(requests.allSatisfy { $0.url?.path == "/orgs/tycho-station/repos" })
    }

    @Test("Verifying an owner surfaces a rejected token")
    func verifyRejectedToken() async {
        let transport = StubTransport { _ in
            .error("Bad credentials", status: 401)
        }
        let client = makeClient(transport)

        do {
            _ = try await client.verifyOwner(login: "alexpricedev", token: "bad")
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case .unauthorized = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("An unknown owner name is reported before the token is saved")
    func verifyUnknownOwner() async {
        let transport = StubTransport { request in
            if request.url?.path == "/user" {
                return .json(Data(#"{"login":"alexpricedev","type":"User"}"#.utf8))
            }
            return .error("Not Found", status: 404)
        }
        let client = makeClient(transport)

        do {
            _ = try await client.verifyOwner(login: "does-not-exist", token: "a-token")
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case let .forbidden(message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(message.contains("does-not-exist"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("A 422 carries GitHub's explanation and the endpoint that failed")
    func validationFailureIsExplained() async {
        let body = Data(#"{"message":"Validation Failed","errors":[{"resource":"Search","field":"q","code":"invalid","message":"The listed users and repositories cannot be searched."}]}"#.utf8)
        let transport = StubTransport { _ in
            .init(status: 422, headers: ["Content-Type": "application/json"], body: body)
        }
        let client = makeClient(transport)

        do {
            _ = try await client.listRepos(account: owner)
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case let .server(status, message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(status == 422)
            #expect(message.contains("The listed users and repositories cannot be searched."))
            #expect(message.contains("/user/repos"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("An unapproved organization's issue search explains the approval wait")
    func organizationSearchNeedsApproval() async {
        let body = Data(#"{"message":"Validation Failed","errors":[{"resource":"Search","field":"q","code":"invalid"}]}"#.utf8)
        let transport = StubTransport { _ in
            .init(status: 422, headers: ["Content-Type": "application/json"], body: body)
        }
        let client = makeClient(transport)

        do {
            _ = try await client.openIssues(
                owner: Owner(login: "wearenaitiv", kind: .organization),
                account: "wearenaitiv"
            )
            Issue.record("Expected an error")
        } catch let error as GitHubError {
            guard case let .forbidden(message) = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
            #expect(message.contains("can't search wearenaitiv's issues"))
            #expect(message.contains("approves it"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
