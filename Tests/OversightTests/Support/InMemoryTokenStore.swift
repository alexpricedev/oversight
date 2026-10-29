import Foundation
@testable import Oversight

struct InMemoryTokenStore: TokenStore {
    final class Storage: @unchecked Sendable {
        private let lock = NSLock()
        private var tokens: [String: String] = [:]

        func token(for owner: String) -> String? {
            lock.withLock { tokens[owner] }
        }

        func set(_ token: String?, for owner: String) {
            lock.withLock { tokens[owner] = token }
        }
    }

    let storage = Storage()

    func token(for owner: String) throws -> String? {
        storage.token(for: owner)
    }

    func save(_ token: String, for owner: String) throws {
        storage.set(token, for: owner)
    }

    func delete(for owner: String) throws {
        storage.set(nil, for: owner)
    }
}
