import Foundation

/// Caps how many requests the client has in flight at once, across every
/// stage of a refresh. The stages run side by side, and GitHub's secondary
/// rate limit punishes a burst of concurrent requests.
actor RequestGate {
    private let limit: Int
    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func enter() async {
        if inFlight < limit {
            inFlight += 1
            return
        }
        // `leave` hands its slot straight to the next waiter, so the count
        // does not change here.
        await withCheckedContinuation { waiters.append($0) }
    }

    func leave() {
        if waiters.isEmpty {
            inFlight -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}
