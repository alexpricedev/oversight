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
        static let includedOrgs = "includedOrgs"
    }

    var owners: [Owner] {
        didSet { persistOwners() }
    }

    var hiddenRepos: Set<String> {
        didSet { persistHiddenRepos() }
    }

    /// Organizations whose repositories the dashboard watches. They are read
    /// with the token of an account that belongs to them, so the set is empty
    /// until the person switches one on in Settings.
    var includedOrgs: Set<String> {
        didSet { persistIncludedOrgs() }
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
        includedOrgs = Set(defaults.stringArray(forKey: Key.includedOrgs) ?? [])

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

    func includesOrg(_ login: String) -> Bool {
        includedOrgs.contains(where: { $0.caseInsensitiveCompare(login) == .orderedSame })
    }

    func includeOrg(_ login: String) {
        guard !includesOrg(login) else { return }
        includedOrgs.insert(login)
    }

    func excludeOrg(_ login: String) {
        guard let existing = includedOrgs.first(where: {
            $0.caseInsensitiveCompare(login) == .orderedSame
        }) else { return }
        includedOrgs.remove(existing)
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

    private func persistIncludedOrgs() {
        defaults.set(Array(includedOrgs).sorted(), forKey: Key.includedOrgs)
    }
}
