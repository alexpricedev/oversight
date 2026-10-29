import Foundation

enum GitHubError: Error, Hashable {
    /// 401, or no token stored for the owner.
    case unauthorized(String)
    /// 403, usually a permission problem with the token.
    case forbidden(String)
    case notFound
    case rateLimited(reset: Date?)
    case server(status: Int, message: String)
    case decoding(String)
    case transport(String)
    case cancelled

    var isAuthenticationFailure: Bool {
        switch self {
        case .unauthorized, .forbidden: true
        default: false
        }
    }

    /// Short enough for a row's tooltip.
    var shortMessage: String {
        switch self {
        case .unauthorized: "Token rejected"
        case .forbidden: "Access denied"
        case .notFound: "Not found"
        case .rateLimited: "Rate limited"
        case let .server(status, _): "GitHub error \(status)"
        case .decoding: "Unreadable response"
        case .transport: "Network error"
        case .cancelled: "Cancelled"
        }
    }

    var userMessage: String {
        switch self {
        case let .unauthorized(message):
            return message
        case let .forbidden(message):
            return message
        case .notFound:
            return "GitHub couldn't find this. It may have been renamed, deleted, or the token can't see it."
        case let .rateLimited(reset):
            if let reset {
                return "GitHub's rate limit is exhausted. It resets at \(reset.formatted(date: .omitted, time: .shortened))."
            }
            return "GitHub's rate limit is exhausted."
        case let .server(status, message):
            return "GitHub returned \(status): \(message)"
        case let .decoding(detail):
            return "GitHub sent a response Oversight couldn't read. \(detail)"
        case let .transport(detail):
            return "Couldn't reach GitHub. \(detail)"
        case .cancelled:
            return "Cancelled."
        }
    }
}

extension GitHubError: LocalizedError {
    var errorDescription: String? {
        userMessage
    }
}
