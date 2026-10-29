import Foundation
@testable import Oversight
import Testing

@MainActor
@Suite("App settings")
struct AppSettingsTests {
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "com.chptrs.oversight.tests.\(UUID().uuidString)")!
    }

    @Test("A fresh install starts with alexpricedev as its owner")
    func seedsDefaultOwner() {
        let settings = AppSettings(defaults: makeDefaults())
        #expect(settings.owners == [Owner(login: "alexpricedev", kind: .user)])
        #expect(settings.hiddenRepos.isEmpty)
    }

    @Test("Owners are persisted")
    func persistsOwners() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults, seedDefaultOwner: false)
        settings.addOwner(Owner(login: "tycho-station", kind: .organization))

        let reloaded = AppSettings(defaults: defaults, seedDefaultOwner: false)
        #expect(reloaded.owners == [Owner(login: "tycho-station", kind: .organization)])
    }

    @Test("Adding an owner with an existing login replaces it")
    func replacesOwnerByLogin() {
        let settings = AppSettings(defaults: makeDefaults(), seedDefaultOwner: false)
        settings.addOwner(Owner(login: "tycho-station", kind: .user))
        settings.addOwner(Owner(login: "TYCHO-STATION", kind: .organization))

        #expect(settings.owners.count == 1)
        #expect(settings.owners.first?.kind == .organization)
    }

    @Test("Removing an owner keeps the rest")
    func removesOwner() {
        let settings = AppSettings(defaults: makeDefaults(), seedDefaultOwner: false)
        settings.addOwner(Owner(login: "alexpricedev", kind: .user))
        settings.addOwner(Owner(login: "tycho-station", kind: .organization))

        settings.removeOwner("alexpricedev")

        #expect(settings.owners == [Owner(login: "tycho-station", kind: .organization)])
    }

    @Test("Hidden repositories are persisted and validated")
    func hiddenRepos() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults, seedDefaultOwner: false)

        settings.hide("alexpricedev/old-lab")
        settings.hide("not-a-slug")
        settings.hide("alexpricedev/atlas/extra")
        #expect(settings.hiddenRepos == ["alexpricedev/old-lab"])

        let reloaded = AppSettings(defaults: defaults, seedDefaultOwner: false)
        #expect(reloaded.hiddenRepos == ["alexpricedev/old-lab"])

        reloaded.unhide("alexpricedev/old-lab")
        #expect(reloaded.hiddenRepos.isEmpty)
    }
}
