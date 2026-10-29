import Foundation

/// The one seam between the client and the network, so tests can serve
/// fixture JSON and inspect the requests that were sent.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.transport("Unexpected response from GitHub.")
        }
        return (data, http)
    }
}
