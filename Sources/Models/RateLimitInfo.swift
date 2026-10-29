import Foundation

struct RateLimitInfo: Hashable {
    let limit: Int
    let remaining: Int
    let reset: Date
    let observedAt: Date

    var fractionRemaining: Double {
        guard limit > 0 else { return 1 }
        return Double(remaining) / Double(limit)
    }

    var isLow: Bool {
        fractionRemaining < 0.1
    }

    /// Parses the rate-limit headers GitHub sends on every response. Returns nil
    /// for buckets other than the core REST bucket, so search's separate 30/min
    /// allowance never overwrites the numbers shown in the footer.
    init?(headers: [AnyHashable: Any], observedAt: Date) {
        var fields: [String: String] = [:]
        for (key, value) in headers {
            fields[String(describing: key).lowercased()] = String(describing: value)
        }
        if let resource = fields["x-ratelimit-resource"], resource != "core" { return nil }
        guard
            let limit = fields["x-ratelimit-limit"].flatMap(Int.init),
            let remaining = fields["x-ratelimit-remaining"].flatMap(Int.init),
            let resetSeconds = fields["x-ratelimit-reset"].flatMap(TimeInterval.init)
        else { return nil }
        self.init(
            limit: limit,
            remaining: remaining,
            reset: Date(timeIntervalSince1970: resetSeconds),
            observedAt: observedAt
        )
    }

    init(limit: Int, remaining: Int, reset: Date, observedAt: Date) {
        self.limit = limit
        self.remaining = remaining
        self.reset = reset
        self.observedAt = observedAt
    }
}
