import Foundation

/// Carries the spectator's typed number between the App Clip and the performer's
/// app, using the same service that already backs `ForceConfigService`.
///
/// The two directions are deliberately asymmetric. The clip runs on a spectator's
/// device and can never hold the write token, so it reports the number without
/// one. Reading it back requires the token, so only the performer sees it. The
/// value is overwritten on every send and is meant to be read live, never stored.
public enum ForcePeekService {
    /// The latest number the spectator typed, with the time it arrived.
    public struct Peek: Equatable {
        /// The display string as the spectator typed it, grouping and all.
        public let value: String
        /// When the service recorded this value.
        public let updatedAt: Date

        public init(value: String, updatedAt: Date) {
            self.value = value
            self.updatedAt = updatedAt
        }
    }

    /// Kept short: a peek that has not arrived quickly is stale by the time it does.
    public static let timeout: TimeInterval = 4

    // MARK: - Write (clip -> service)

    /// Reports the spectator's current display value. No token: the clip cannot
    /// hold one. Errors are the caller's to swallow, since a dropped peek must
    /// never disturb the calculator.
    public static func send(
        _ value: String,
        session: URLSession = .shared,
        id: String = ForceConfigService.performerID
    ) async throws {
        var request = URLRequest(url: try peekURL(id: id))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        request.httpBody = try JSONSerialization.data(withJSONObject: ["value": value])

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    // MARK: - Read (service -> performer)

    /// Fetches the latest reported number, or nil when nothing has been reported
    /// for this performer yet.
    ///
    /// - Throws: `ForceConfigService.ServiceError.unauthorized` when the token is
    ///   missing or wrong.
    public static func fetch(
        token: String,
        session: URLSession = .shared,
        id: String = ForceConfigService.performerID
    ) async throws -> Peek? {
        var request = URLRequest(url: try peekURL(id: id))
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // The spectator may have typed another digit a moment ago, so never reuse
        // a cached response.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await session.data(for: request)
        do {
            try validate(response)
        } catch ForceConfigService.ServiceError.notPublished {
            return nil
        }
        return try decode(data)
    }

    // MARK: - Helpers

    private static func decode(_ data: Data) throws -> Peek {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["value"] as? String,
              let millis = object["updatedAt"] as? Double else {
            throw ForceConfigService.ServiceError.malformedResponse
        }
        return Peek(value: value, updatedAt: Date(timeIntervalSince1970: millis / 1000))
    }

    private static func peekURL(id: String) throws -> URL {
        var components = URLComponents(
            url: ForceConfigService.baseURL.appendingPathComponent("v1/peek"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "id", value: id)]
        guard let url = components?.url else {
            throw ForceConfigService.ServiceError.malformedResponse
        }
        return url
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ForceConfigService.ServiceError.malformedResponse
        }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw ForceConfigService.ServiceError.unauthorized
        case 404:
            throw ForceConfigService.ServiceError.notPublished
        default:
            throw ForceConfigService.ServiceError.server(status: http.statusCode)
        }
    }
}
