import Foundation

struct RepoID: Identifiable, Hashable, Codable, CustomStringConvertible {
    let owner: String
    let name: String

    var id: String {
        slug
    }

    var slug: String {
        "\(owner)/\(name)"
    }

    var description: String {
        slug
    }

    init(owner: String, name: String) {
        self.owner = owner
        self.name = name
    }

    init?(slug: String) {
        let parts = slug.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty,
              !parts[1].contains("/")
        else { return nil }
        self.init(owner: String(parts[0]), name: String(parts[1]))
    }
}

struct Repo: Identifiable, Hashable {
    let id: RepoID
    let isPrivate: Bool
    let isFork: Bool
    let isArchived: Bool
    let pushedAt: Date?
    let defaultBranch: String

    var name: String {
        id.name
    }

    var owner: String {
        id.owner
    }

    init(
        id: RepoID,
        isPrivate: Bool = false,
        isFork: Bool = false,
        isArchived: Bool = false,
        pushedAt: Date? = nil,
        defaultBranch: String = "main"
    ) {
        self.id = id
        self.isPrivate = isPrivate
        self.isFork = isFork
        self.isArchived = isArchived
        self.pushedAt = pushedAt
        self.defaultBranch = defaultBranch
    }
}
