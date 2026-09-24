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
    private static let cacheLock = NSLock()
    private static var cached: [String: (identifier: String, writeToken: String)] = [:]

    /// The identity to publish under, creating one on first use.
    ///
    /// - Parameter service: Keychain service. Tests pass their own so they never
    ///   share, or wipe, the performer's record.
    static func current(
        service: String = ConfigTokenStore.productionService
    ) -> (identifier: String, writeToken: String) {
        cacheLock.lock()
        if let existing = cached[service] {
            cacheLock.unlock()
            return existing
        }
        cacheLock.unlock()

        let resolved = resolve(service: service)
        cacheLock.lock()
        if let existing = cached[service] {
            cacheLock.unlock()
            return existing
        }
        cached[service] = resolved
        cacheLock.unlock()
        return resolved
    }

    static var identifier: String { current().identifier }
    static var writeToken: String { current().writeToken }

    /// Forgets one cached identity so the next read comes from the Keychain. Tests only.
    static func forgetCache(service: String = ConfigTokenStore.productionService) {
        cacheLock.lock()
        cached.removeValue(forKey: service)
        cacheLock.unlock()
    }

    private static func resolve(
        service: String
    ) -> (identifier: String, writeToken: String) {
        let storedToken = ConfigTokenStore.load(service: service)

        if let id = ConfigTokenStore.load(
            account: ConfigTokenStore.performerAccount,
            service: service
        ) {
            return (id, storedToken ?? makeToken(service: service))
        }

        // No id stored yet. A token already here means this install was publishing under
        // the shared id before performers had their own, so it keeps both: the record it
        // owns and the tags already pointing at it stay valid.
        if let storedToken {
            ConfigTokenStore.save(
                PerformerID.shared,
                account: ConfigTokenStore.performerAccount,
                service: service
            )
            debugLog("🔑 Kept the shared performer id for an install that already published")
            return (PerformerID.shared, storedToken)
        }

        let id = PerformerID.generate()
        ConfigTokenStore.save(id, account: ConfigTokenStore.performerAccount, service: service)
        debugLog("🔑 Claimed a new performer id")
        return (id, makeToken(service: service))
    }

    private static func makeToken(service: String) -> String {
        let token = PerformerID.generateToken()
        ConfigTokenStore.save(token, service: service)
        return token
    }
}
