import Foundation
import Observation

/// Everything the views and settings window share.
@MainActor
@Observable
final class AppEnvironment {
    let settings: AppSettings
    let tokenStore: any TokenStore
    let client: any GitHubClientProtocol
    let model: DashboardModel
    let activity: AppActivity

    init(
        settings: AppSettings,
        tokenStore: any TokenStore,
        client: any GitHubClientProtocol,
        clock: any Clocking = SystemClock(),
        activity: AppActivity = AppActivity()
    ) {
        self.settings = settings
        self.tokenStore = tokenStore
        self.client = client
        self.activity = activity
        model = DashboardModel(client: client, settings: settings, clock: clock)
    }

    static func live() -> AppEnvironment {
        // `--demo` runs the real app against believable fake data: no token,
        // no Keychain, no network. Used for screenshots.
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            let defaults = UserDefaults(suiteName: "com.chptrs.oversight.demo") ?? .standard
            let settings = AppSettings(defaults: defaults, seedDefaultOwner: false)
            for owner in settings.owners where owner.login != DemoData.owner.login {
                settings.removeOwner(owner.login)
            }
            settings.addOwner(DemoData.owner)
            return AppEnvironment(
                settings: settings,
                tokenStore: DemoTokenStore(),
                client: DemoGitHubClient()
            )
        }

        let settings = AppSettings()
        let tokenStore = KeychainTokenStore()
        let client = GitHubAPIClient(tokenProvider: { login in
            (try? tokenStore.token(for: login)) ?? nil
        })
        return AppEnvironment(settings: settings, tokenStore: tokenStore, client: client)
    }

    var repoFilter: String {
        get { model.repoFilter }
        set { model.repoFilter = newValue }
    }

    var ownerFilter: String? {
        get { model.ownerFilter }
        set { model.ownerFilter = newValue }
    }
}
