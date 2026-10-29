import Foundation

/// How often each kind of thing is polled. Repositories with a run in progress
/// are polled hard, repositories pushed to recently are polled gently, and
/// everything else every ten minutes.
struct PollCadence: Hashable {
    var activeInterval: TimeInterval = 15
    var recentInterval: TimeInterval = 60
    var idleInterval: TimeInterval = 600
    var repoListInterval: TimeInterval = 600
    var searchInterval: TimeInterval = 60
    var recentWindow: TimeInterval = 7 * 24 * 60 * 60

    func repoInterval(hasRunningRun: Bool, lastPush: Date?, now: Date) -> TimeInterval {
        if hasRunningRun { return activeInterval }
        guard let lastPush else { return idleInterval }
        return now.timeIntervalSince(lastPush) <= recentWindow ? recentInterval : idleInterval
    }
}

/// Slows every poll down when a token is close to its hourly limit. With a
/// tenth of the allowance left, intervals are multiplied; at zero, the next
/// poll waits for the reset.
struct RateLimitGovernor: Hashable {
    var lowWatermark: Double = 0.1
    var slowFactor: Double = 4

    func interval(base: TimeInterval, info: RateLimitInfo?, now: Date) -> TimeInterval {
        guard let info else { return base }
        if info.remaining <= 0, info.reset > now {
            return max(base, info.reset.timeIntervalSince(now) + 1)
        }
        guard info.fractionRemaining < lowWatermark else { return base }
        return base * slowFactor
    }

    func isThrottled(info: RateLimitInfo?) -> Bool {
        guard let info else { return false }
        return info.fractionRemaining < lowWatermark
    }
}
