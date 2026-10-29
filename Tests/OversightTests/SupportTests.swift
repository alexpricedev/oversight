import Foundation
@testable import Oversight
import Testing

@Suite("Rate limit headers")
struct RateLimitInfoTests {
    private let now = Sample.date("2026-10-29T12:00:00Z")

    private func headers(
        limit: String = "5000",
        remaining: String = "4999",
        reset: String = "1793000000",
        resource: String? = "core"
    ) -> [AnyHashable: Any] {
        var headers: [AnyHashable: Any] = [
            "x-ratelimit-limit": limit,
            "x-ratelimit-remaining": remaining,
            "x-ratelimit-reset": reset,
        ]
        if let resource {
            headers["x-ratelimit-resource"] = resource
        }
        return headers
    }

    @Test("Core bucket headers are parsed")
    func parsesCoreHeaders() throws {
        let info = try #require(RateLimitInfo(headers: headers(), observedAt: now))
        #expect(info.limit == 5000)
        #expect(info.remaining == 4999)
        #expect(info.reset == Date(timeIntervalSince1970: 1_793_000_000))
        #expect(info.isLow == false)
    }

    @Test("Search's separate bucket is ignored")
    func ignoresSearchBucket() {
        #expect(RateLimitInfo(headers: headers(resource: "search"), observedAt: now) == nil)
    }

    @Test("Missing headers mean no update")
    func missingHeaders() {
        let partial: [AnyHashable: Any] = ["x-ratelimit-limit": "5000"]
        #expect(RateLimitInfo(headers: partial, observedAt: now) == nil)
    }

    @Test("Low means below ten percent")
    func lowWatermark() {
        let low = RateLimitInfo(limit: 5000, remaining: 499, reset: now, observedAt: now)
        let fine = RateLimitInfo(limit: 5000, remaining: 500, reset: now, observedAt: now)
        #expect(low.isLow)
        #expect(fine.isLow == false)
    }
}

@Suite("ETag cache")
struct ETagCacheTests {
    @Test("Entries round-trip per key")
    func roundTrip() async {
        let cache = ETagCache()
        let entry = ETagCache.Entry(etag: "\"abc\"", data: Data("{}".utf8))
        await cache.store(entry, for: "alexpricedev|https://api.github.com/user/repos")

        let found = await cache.entry(for: "alexpricedev|https://api.github.com/user/repos")
        #expect(found == entry)
    }

    @Test("The same URL under two tokens has two entries")
    func perTokenIsolation() async {
        let cache = ETagCache()
        await cache.store(.init(etag: "\"one\"", data: Data("1".utf8)), for: "owner-a|https://api.github.com/user")
        await cache.store(.init(etag: "\"two\"", data: Data("2".utf8)), for: "owner-b|https://api.github.com/user")

        let a = await cache.entry(for: "owner-a|https://api.github.com/user")
        let b = await cache.entry(for: "owner-b|https://api.github.com/user")
        #expect(a?.etag == "\"one\"")
        #expect(b?.etag == "\"two\"")
    }
}

@Suite("Formatting")
struct FormattingTests {
    private let now = Sample.date("2026-10-29T12:00:00Z")

    @Test("Relative times read naturally")
    func relativeTime() {
        #expect(RelativeTime.ago(now.addingTimeInterval(-10), now: now) == "just now")
        #expect(RelativeTime.ago(now.addingTimeInterval(-60 * 5), now: now) == "5m ago")
        #expect(RelativeTime.ago(now.addingTimeInterval(-3600 * 4), now: now) == "4h ago")
        #expect(RelativeTime.ago(now.addingTimeInterval(-86400 * 3), now: now) == "3d ago")
        #expect(RelativeTime.ago(now.addingTimeInterval(-604_800 * 2), now: now) == "2w ago")
        #expect(RelativeTime.ago(now.addingTimeInterval(-2_592_000 * 3), now: now) == "3mo ago")
    }

    @Test("Elapsed clocks and durations are distinguishable")
    func elapsed() {
        #expect(Elapsed.clock(7) == "0:07")
        #expect(Elapsed.clock(725) == "12:05")
        #expect(Elapsed.clock(3753) == "1:02:33")

        #expect(Elapsed.short(7) == "7s")
        #expect(Elapsed.short(64) == "1m 04s")
        #expect(Elapsed.short(7500) == "2h 05m")
    }
}
