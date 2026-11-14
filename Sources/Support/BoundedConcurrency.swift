import Foundation

/// Runs `operation` over `items` with at most `limit` in flight, and hands each
/// result to `onResult` on the main actor as soon as it arrives, so the
/// dashboard can show it without waiting for the slowest request.
@MainActor
func forEachConcurrently<Item: Sendable, Output: Sendable>(
    _ items: [Item],
    limit: Int,
    operation: @escaping @Sendable (Item) async -> Output,
    onResult: (Output) -> Void
) async {
    guard !items.isEmpty else { return }
    await withTaskGroup(of: Output.self) { group in
        var iterator = items.makeIterator()
        for _ in 0 ..< max(1, limit) {
            guard let item = iterator.next() else { break }
            group.addTask { await operation(item) }
        }
        while let output = await group.next() {
            onResult(output)
            if let item = iterator.next() {
                group.addTask { await operation(item) }
            }
        }
    }
}

/// Measures one stage of a refresh for the `refresh` log.
struct StageTimer {
    private let start = ContinuousClock.now

    var elapsed: String {
        let duration = ContinuousClock.now - start
        let seconds = Double(duration.components.seconds)
            + Double(duration.components.attoseconds) / 1e18
        return String(format: "%.2fs", seconds)
    }
}
