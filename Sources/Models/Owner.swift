import Foundation

enum OwnerKind: String, Codable, CaseIterable {
    case user
    case organization

    /// The GitHub search qualifier for this kind of owner.
    var searchQualifier: String {
        switch self {
        case .user: "user"
        case .organization: "org"
        }
    }

    var displayName: String {
        switch self {
        case .user: "User"
        case .organization: "Organization"
        }
    }
}

struct Owner: Identifiable, Hashable, Codable {
    let login: String
    let kind: OwnerKind

    var id: String {
        login
    }
}
