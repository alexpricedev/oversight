import Foundation

/// Stores the last good response body and its ETag per request URL, so a 304
/// can be served from memory instead of being reported as a failure.
actor ETagCache {
    struct Entry: Hashable {
        let etag: String
        let data: Data
    }

    private var entries: [String: Entry] = [:]

    func entry(for key: String) -> Entry? {
        entries[key]
    }

    func store(_ entry: Entry, for key: String) {
        entries[key] = entry
    }

    func removeAll() {
        entries.removeAll()
    }

    var count: Int {
        entries.count
    }
}
