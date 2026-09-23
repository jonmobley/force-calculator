import Foundation
import Security

/// Keychain storage for the performer's config service credentials.
///
/// Two values live here under separate accounts: the write token, which proves a
/// publish is really the performer's, and the performer id naming their record. Neither
/// is written into the shared app group, so the App Clip can never read them. Only the
/// performer's app publishes settings; the clip only reads them.
///
/// The Keychain outlives a delete and reinstall, which matters: the id is printed on
/// every QR code and NFC tag in circulation, so losing it would strand them all.
enum ConfigTokenStore {
    private static let service = "com.mobleypro.mobley.Force.configWriteToken"

    /// The write token's account. Named `default` because that is where it has always
    /// been stored, and renaming it would orphan the token on existing installs.
    static let tokenAccount = "default"
    static let performerAccount = "performerID"

    /// Returns the stored value, or nil when there is none.
    static func load(account: String = tokenAccount) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8),
              !token.isEmpty else {
            return nil
        }
        return token
    }

    /// Stores the value, replacing any previous one. An empty string clears it.
    @discardableResult
    static func save(_ token: String, account: String = tokenAccount) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return delete(account: account) }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(trimmed.utf8),
            // The app publishes when it moves to the background, so the token has
            // to be readable while the device is locked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        return SecItemAdd(query.merging(attributes) { $1 } as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func delete(account: String = tokenAccount) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
