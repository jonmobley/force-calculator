import Foundation

/// Reads and writes the performer's settings on the config service.
///
/// The App Clip runs on a spectator's device and cannot see the performer's app
/// group, so it fetches settings from here at launch. That keeps a written NFC
/// tag or printed QR code valid forever instead of freezing the settings that
/// happened to be active when the tag was written.
public enum ForceConfigService {
    /// Deployed Cloudflare Worker backed by D1.
    public static let baseURL = URL(string: "https://force-config.jonmobley.workers.dev")!

    /// Kept short: this runs during App Clip launch, where latency is visible.
    public static let fetchTimeout: TimeInterval = 4

    public enum ServiceError: Error, Equatable {
        /// The write token was missing or wrong.
        case unauthorized
        /// No settings have been published yet.
        case notPublished
        case server(status: Int)
        case malformedResponse
    }

    // MARK: - Read

    /// Fetches the performer's current settings.
    ///
    /// - Throws: `ServiceError.notPublished` when the performer has never
    ///   published, which callers should treat as "keep what you already have".
    public static func fetch(
        id: String,
        session: URLSession = .shared
    ) async throws -> CalculatorSettings {
        var request = URLRequest(url: try configURL(id: id))
        request.httpMethod = "GET"
        request.timeoutInterval = fetchTimeout
        // The force number may have changed seconds ago, so never reuse a cached
        // response.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        try validate(response)
        do {
            return try JSONDecoder().decode(CalculatorSettings.self, from: data)
        } catch {
            throw ServiceError.malformedResponse
        }
    }

    // MARK: - Write

    /// Replaces the stored settings. Only the performer's own app calls this.
    public static func publish(
        _ settings: CalculatorSettings,
        id: String,
        token: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try configURL(id: id))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(settings)

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    // MARK: - Helpers

    private static func configURL(id: String) throws -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("v1/config"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else { throw ServiceError.malformedResponse }
        return url
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ServiceError.malformedResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw ServiceError.unauthorized
        case 404:
            throw ServiceError.notPublished
        default:
            throw ServiceError.server(status: http.statusCode)
        }
    }
}

public extension CalculatorSettings {
    /// Detached copy of the current values.
    ///
    /// Uploads are asynchronous, so the caller snapshots first to guarantee that
    /// a later edit cannot change what is already in flight.
    func snapshot() -> CalculatorSettings {
        let copy = CalculatorSettings()
        copy.applyStored(self)
        return copy
    }
}
