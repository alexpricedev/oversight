import Foundation
import Security

protocol TokenStore: Sendable {
    func token(for owner: String) throws -> String?
    func save(_ token: String, for owner: String) throws
    func delete(for owner: String) throws
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus

    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return message
        }
        return "Keychain error \(status)."
    }
}
