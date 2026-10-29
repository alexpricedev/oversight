import Foundation
@testable import Oversight

final class TestClock: Clocking, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ now: Date = Sample.date("2026-10-29T12:00:00Z")) {
        current = now
    }

    var now: Date {
        lock.withLock { current }
    }

    func advance(_ interval: TimeInterval) {
        lock.withLock { current = current.addingTimeInterval(interval) }
    }

    func set(_ date: Date) {
        lock.withLock { current = date }
    }
}
