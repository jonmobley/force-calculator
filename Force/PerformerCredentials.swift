import Foundation
import ForceShared

/// The performer's identity on the config service: which record is theirs, and the
/// secret that proves it.
///
/// Both are generated on this device the first time they are needed, so there is nothing
/// for the performer to set up and no token to copy between devices. The id is public and
/// travels on every QR code; the token stays in the Keychain and is sent only as a bearer
/// header when publishing.
///
/// The service binds an id to the first token that writes it, so generating locally is
/// enough to claim a record that nobody else can then overwrite.
enum PerformerCredentials {
    private static var cached: (identifier: String, writeToken: String)?

    /// The identity to publish under, creating one on first use.
    static func current() -> (identifier: String, writeToken: String) {
        if let cached { return cached }
        let resolved = resolve()
        cached = resolved
        return resolved
    }

    static var identifier: String { current().identifier }
    static var writeToken: String { current().writeToken }

    /// Forgets the cached value so the next read comes from the Keychain. Tests only.
    static func forgetCache() {
        cached = nil
    }

    private static func resolve() -> (identifier: String, writeToken: String) {
        let storedToken = ConfigTokenStore.load()

        if let id = ConfigTokenStore.load(account: ConfigTokenStore.performerAccount) {
            return (id, storedToken ?? makeToken())
        }

        // No id stored yet. A token already here means this install was publishing under
        // the shared id before performers had their own, so it keeps both: the record it
        // owns and the tags already pointing at it stay valid.
        if let storedToken {
            ConfigTokenStore.save(PerformerID.shared, account: ConfigTokenStore.performerAccount)
            debugLog("🔑 Kept the shared performer id for an install that already published")
            return (PerformerID.shared, storedToken)
        }

        let id = PerformerID.generate()
        ConfigTokenStore.save(id, account: ConfigTokenStore.performerAccount)
        debugLog("🔑 Claimed a new performer id")
        return (id, makeToken())
    }

    private static func makeToken() -> String {
        let token = PerformerID.generateToken()
        ConfigTokenStore.save(token)
        return token
    }
}
