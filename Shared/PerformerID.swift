import Foundation
import Security

/// Identifies whose settings the config service should serve.
///
/// Every install used to publish to the single id `default`, which meant one shared
/// record for everybody: a second performer changing their force number overwrote the
/// first performer's, and live peek showed whichever spectator had typed most recently,
/// on anyone's phone. Each install now owns a random id instead, and the id travels on
/// the App Clip URL so the spectator's clip reads the right record.
///
/// The id is not a secret. It is printed into every QR code and written onto every NFC
/// tag, exactly as `default` was. What keeps another install from writing to it is the
/// write token, which never leaves the performer's Keychain.
public enum PerformerID {
    /// The id shared by every install before this existed. Kept so a performer who was
    /// already publishing keeps their record, along with the tags pointing at it.
    public static let shared = "default"

    /// Bytes of randomness behind a generated id. Ids are guessable in principle, since
    /// reading a config needs no token, so there has to be enough here that nobody can
    /// enumerate their way to somebody else's force number.
    private static let entropyBytes = 16

    /// A fresh id, in the `[A-Za-z0-9_-]{1,64}` alphabet the service accepts.
    public static func generate() -> String {
        var bytes = [UInt8](repeating: 0, count: entropyBytes)
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            // Practically unreachable, and an id is not a secret. Falling back keeps the
            // performer publishing rather than failing setup over the randomness source.
            bytes = (0..<entropyBytes).map { _ in UInt8.random(in: .min ... .max) }
        }
        return urlSafeBase64(Data(bytes))
    }

    /// A fresh write token. Same generator, more of it: this one is a secret.
    public static func generateToken() -> String {
        generate() + generate()
    }

    public static func isValid(_ id: String) -> Bool {
        guard !id.isEmpty, id.count <= 64 else { return false }
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        return id.unicodeScalars.allSatisfy(allowed.contains)
    }

    /// Base64 without the characters the service's id pattern rejects.
    private static func urlSafeBase64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
