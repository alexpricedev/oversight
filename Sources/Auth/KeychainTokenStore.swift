import Foundation
import Security

/// Stores one GitHub token per owner as a generic password in the login
/// keychain. Nothing secret touches UserDefaults or disk.
struct KeychainTokenStore: TokenStore {
    let service: String

    init(service: String = "com.chptrs.oversight.tokens") {
        self.service = service
    }

    func token(for owner: String) throws -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: owner,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        // Avoid an interactive prompt: this app is read-only and only ever
        // reads its own items.
        query[kSecUseDataProtectionKeychain as String] = false

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    func save(_ token: String, for owner: String) throws {
        let data = Data(token.utf8)
        let lookup: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: owner,
            kSecUseDataProtectionKeychain as String: false,
        ]
        let changes: [String: Any] = [
            kSecValueData as String: data,
        ]

        let updateStatus = SecItemUpdate(lookup as CFDictionary, changes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = lookup
            insert[kSecValueData as String] = data
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
        default:
            throw KeychainError(status: updateStatus)
        }
    }

    func delete(for owner: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: owner,
            kSecUseDataProtectionKeychain as String: false,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}
