import Foundation
@testable import Oversight

/// Serves canned responses and records what the client asked for.
actor StubTransport: HTTPTransport {
    struct Response {
        var status: Int
        var headers: [String: String]
        var body: Data

        init(status: Int = 200, headers: [String: String] = [:], body: Data = Data()) {
            self.status = status
            self.headers = headers
            self.body = body
        }

        static func json(_ data: Data, status: Int = 200, headers: [String: String] = [:]) -> Response {
            Response(status: status, headers: headers, body: data)
        }

        static func error(_ message: String, status: Int) -> Response {
            Response(
                status: status,
                headers: ["Content-Type": "application/json"],
                body: Data("{\"message\":\"\(message)\"}".utf8)
            )
        }
    }

    typealias Handler = @Sendable (URLRequest) async throws -> Response

    private let handler: Handler
    private var requests: [URLRequest] = []

    init(_ handler: @escaping Handler) {
        self.handler = handler
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = try await handler(request)
        guard let url = request.url,
              let http = HTTPURLResponse(
                  url: url,
                  statusCode: response.status,
                  httpVersion: "HTTP/1.1",
                  headerFields: response.headers
              )
        else {
            throw GitHubError.transport("Stub transport could not build a response.")
        }
        return (response.body, http)
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}
