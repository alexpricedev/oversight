import Foundation

/// The most recent rate-limit numbers seen for each owner's token.
actor RateLimitLedger {
    private var latest: [String: RateLimitInfo] = [:]

    func record(_ info: RateLimitInfo, for owner: String) {
        latest[owner] = info
    }

    func info(for owner: String) -> RateLimitInfo? {
        latest[owner]
    }

    func all() -> [String: RateLimitInfo] {
        latest
    }
}
