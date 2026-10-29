import Foundation
@testable import Oversight
import Testing

@Suite("Polling cadence")
struct PollCadenceTests {
    private let cadence = PollCadence()
    private let now = Sample.date("2026-10-29T12:00:00Z")

    @Test("A repo with a run in progress polls every 15 seconds")
    func runningRepo() {
        #expect(cadence.repoInterval(hasRunningRun: true, lastPush: now, now: now) == 15)
    }

    @Test("A repo pushed to in the last week polls every minute")
    func recentlyPushedRepo() {
        let twoDaysAgo = now.addingTimeInterval(-2 * 86400)
        #expect(cadence.repoInterval(hasRunningRun: false, lastPush: twoDaysAgo, now: now) == 60)
    }

    @Test("An older repo polls every ten minutes")
    func idleRepo() {
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 86400)
        #expect(cadence.repoInterval(hasRunningRun: false, lastPush: thirtyDaysAgo, now: now) == 600)
    }

    @Test("A repo that has never been pushed polls every ten minutes")
    func neverPushedRepo() {
        #expect(cadence.repoInterval(hasRunningRun: false, lastPush: nil, now: now) == 600)
    }

    @Test("The repo list and search have their own fixed cadence")
    func fixedCadences() {
        #expect(cadence.repoListInterval == 600)
        #expect(cadence.searchInterval == 60)
    }
}

@Suite("Rate limit backoff")
struct RateLimitGovernorTests {
    private let governor = RateLimitGovernor()
    private let now = Sample.date("2026-10-29T12:00:00Z")

    private func info(remaining: Int, limit: Int = 5000, resetIn: TimeInterval = 1800) -> RateLimitInfo {
        RateLimitInfo(
            limit: limit,
            remaining: remaining,
            reset: now.addingTimeInterval(resetIn),
            observedAt: now
        )
    }

    @Test("With no rate-limit data the interval is unchanged")
    func noData() {
        #expect(governor.interval(base: 60, info: nil, now: now) == 60)
    }

    @Test("Plenty of allowance leaves the interval alone")
    func plentyLeft() {
        #expect(governor.interval(base: 60, info: info(remaining: 4500), now: now) == 60)
    }

    @Test("Below ten percent remaining, polling slows down four times")
    func lowAllowance() {
        #expect(governor.interval(base: 60, info: info(remaining: 450), now: now) == 240)
        #expect(governor.interval(base: 15, info: info(remaining: 450), now: now) == 60)
    }

    @Test("Exactly ten percent is not yet slow")
    func tenPercentBoundary() {
        #expect(governor.interval(base: 60, info: info(remaining: 500), now: now) == 60)
    }

    @Test("At zero the next poll waits for the reset")
    func exhausted() {
        let interval = governor.interval(base: 60, info: info(remaining: 0, resetIn: 300), now: now)
        #expect(interval == 301)
    }

    @Test("An exhausted limit whose reset has passed goes back to the slow interval")
    func staleReset() {
        let interval = governor.interval(base: 60, info: info(remaining: 0, resetIn: -10), now: now)
        #expect(interval == 240)
    }
}

@Suite("Poll planner")
struct PollPlannerTests {
    private let now = Sample.date("2026-10-29T12:00:00Z")
    private let repo = Sample.atlas.id

    @Test("A key that has never been polled is due")
    func unscheduledIsDue() {
        let planner = PollPlanner()
        #expect(planner.isDue(.runs(repo), at: now))
    }

    @Test("Scheduling keeps a key out of the next pass until its interval passes")
    func scheduling() {
        var planner = PollPlanner()
        planner.schedule(.runs(repo), in: 15, from: now)

        #expect(planner.isDue(.runs(repo), at: now) == false)
        #expect(planner.isDue(.runs(repo), at: now.addingTimeInterval(14)) == false)
        #expect(planner.isDue(.runs(repo), at: now.addingTimeInterval(15)) == true)
        #expect(planner.dueKeys(at: now).isEmpty)
        #expect(planner.dueKeys(at: now.addingTimeInterval(15)) == [.runs(repo)])
    }

    @Test("The loop wakes at the earliest due time")
    func nextWake() {
        var planner = PollPlanner()
        planner.schedule(.runs(repo), in: 60, from: now)
        planner.schedule(.search("alexpricedev"), in: 15, from: now)
        planner.schedule(.repos("alexpricedev"), in: 600, from: now)

        #expect(planner.nextWake(after: now) == now.addingTimeInterval(15))
    }

    @Test("Marking everything due on a manual refresh")
    func markAllDue() {
        var planner = PollPlanner()
        planner.schedule(.runs(repo), in: 600, from: now)
        planner.schedule(.search("alexpricedev"), in: 600, from: now)
        planner.markAllDue(at: now)

        #expect(planner.isDue(.runs(repo), at: now))
        #expect(planner.isDue(.search("alexpricedev"), at: now))
        #expect(planner.nextWake(after: now) == nil)
    }

    @Test("Pruning drops keys for owners and repos that are gone")
    func retain() {
        var planner = PollPlanner()
        planner.schedule(.repos("alexpricedev"), in: 600, from: now)
        planner.schedule(.repos("removed-owner"), in: 600, from: now)
        planner.schedule(.runs(repo), in: 600, from: now)

        planner.retain([.repos("alexpricedev"), .runs(repo)])

        #expect(planner.dueKeys(at: now.addingTimeInterval(1000)).contains(.repos("alexpricedev")))
        #expect(planner.dueKeys(at: now.addingTimeInterval(1000)).contains(.runs(repo)))
        #expect(planner.dueKeys(at: now.addingTimeInterval(1000)).count == 2)
    }
}
