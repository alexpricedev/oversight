import Foundation
import Observation

/// Owners and hidden repositories. Only these non-secret preferences live in
/// UserDefaults; tokens are in the Keychain.
@MainActor
@Observable
final class AppSettings {
    private let defaults: UserDefaults

    private enum Key {
        static let owners = "owners"
        static let hiddenRepos = "hiddenRepos"
    }

    var owners: [Owner] {
        didSet { persistOwners() }
    }

    var hiddenRepos: Set<String> {
        didSet { persistHiddenRepos() }
    }

    init(defaults: UserDefaults = .standard, seedDefaultOwner: Bool = true) {
        self.defaults = defaults

        var seededOwner = false
        if let data = defaults.data(forKey: Key.owners),
           let decoded = try? JSONDecoder().decode([Owner].self, from: data)
        {
            owners = decoded
        } else {
            // The first owner is alexpricedev; their token is added in Settings.
            owners = seedDefaultOwner ? [Owner(login: "alexpricedev", kind: .user)] : []
            seededOwner = true
        }

        hiddenRepos = Set(defaults.stringArray(forKey: Key.hiddenRepos) ?? [])

        if seededOwner {
            persistOwners()
        }
    }

    func addOwner(_ owner: Owner) {
        if let index = owners.firstIndex(where: { $0.login.caseInsensitiveCompare(owner.login) == .orderedSame }) {
            owners[index] = owner
        } else {
            owners.append(owner)
        }
        owners.sort { $0.login.localizedStandardCompare($1.login) == .orderedAscending }
    }

    func removeOwner(_ login: String) {
        owners.removeAll { $0.login.caseInsensitiveCompare(login) == .orderedSame }
    }

    func hide(_ slug: String) {
        let trimmed = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RepoID(slug: trimmed) != nil else { return }
        hiddenRepos.insert(trimmed)
    }

    func unhide(_ slug: String) {
        hiddenRepos.remove(slug)
    }

    private func persistOwners() {
        guard let data = try? JSONEncoder().encode(owners) else { return }
        defaults.set(data, forKey: Key.owners)
    }

    private func persistHiddenRepos() {
        defaults.set(Array(hiddenRepos).sorted(), forKey: Key.hiddenRepos)
    }
}
