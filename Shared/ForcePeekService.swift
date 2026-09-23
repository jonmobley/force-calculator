import Foundation

/// Carries the spectator's typed number between the App Clip and the performer's
/// app, using the same service that already backs `ForceConfigService`.
///
/// The two directions are deliberately asymmetric. The clip runs on a spectator's
/// device and can never hold the write token, so it reports the number without
/// one. Reading it back requires the token, so only the performer sees it. The
/// value is overwritten on every send and is meant to be read live, never stored.
public enum ForcePeekService {
    /// One number from the spectator's calculation, and the key that ended it.
    ///
    /// Entries are reported twice: once when the number settles, and again with `op`
    /// filled in when the spectator presses an operator. The second report carries the
    /// same `id`, so it updates that entry rather than adding another.
    public struct Entry: Equatable, Identifiable {
        /// Minted by the clip, unique within a session.
        public let id: String
        /// The display string as the spectator typed it, grouping and all.
        public let value: String
        /// The key pressed after this number, or nil while it is still the live one.
        public let op: String?
        /// When the service recorded it.
        public let at: Date

        public init(id: String, value: String, op: String? = nil, at: Date) {
            self.id = id
            self.value = value
            self.op = op
            self.at = at
        }

        /// How the entry reads on one line: the number, then the key that closed it.
        public var line: String {
            guard let op else { return value }
            return "\(value) \(op)"
        }
    }

    /// The spectator's calculation so far, oldest first.
    public struct Peek: Equatable {
        public let entries: [Entry]

        public init(entries: [Entry]) {
            self.entries = entries
        }

        /// The number currently on the spectator's screen.
        public var latest: Entry? { entries.last }

        /// When anything was last reported, used to decide whether this is still live.
        public var updatedAt: Date { entries.last?.at ?? .distantPast }
    }

    /// Kept short: a peek that has not arrived quickly is stale by the time it does.
    public static let timeout: TimeInterval = 4

    // MARK: - Write (clip -> service)

    /// Reports one number from the spectator's calculation. No token: the clip cannot
    /// hold one. Errors are the caller's to swallow, since a dropped peek must
    /// never disturb the calculator.
    ///
    /// Sending the same `entryID` again replaces that entry, which is how a number
    /// already on the performer's screen gains the operator that ended it.
    public static func send(
        _ value: String,
        entryID: String,
        op: String? = nil,
        id: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try peekURL(id: id))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout
        var body: [String: String] = ["value": value, "entryID": entryID]
        body["op"] = op
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    /// Wipes the calculation so the next spectator starts on a clean readout.
    public static func clear(
        id: String,
        token: String,
        session: URLSession = .shared
    ) async throws {
        var request = URLRequest(url: try peekURL(id: id))
        request.httpMethod = "DELETE"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    // MARK: - Read (service -> performer)

    /// Fetches the calculation so far, or nil when nothing has been reported
    /// for this performer yet.
    ///
    /// - Throws: `ForceConfigService.ServiceError.unauthorized` when the token is
    ///   missing or wrong.
    public static func fetch(
        id: String,
        token: String,
        session: URLSession = .shared
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
              let rows = object["entries"] as? [[String: Any]] else {
            throw ForceConfigService.ServiceError.malformedResponse
        }
        let entries = rows.enumerated().compactMap { index, row -> Entry? in
            guard let value = row["value"] as? String,
                  let millis = row["at"] as? Double else { return nil }
            return Entry(
                // The service keys entries by its own column; the index is enough to
                // keep them distinct for SwiftUI within one response.
                id: "\(index)-\(millis)",
                value: value,
                op: row["op"] as? String,
                at: Date(timeIntervalSince1970: millis / 1000)
            )
        }
        guard !entries.isEmpty else {
            throw ForceConfigService.ServiceError.malformedResponse
        }
        return Peek(entries: entries)
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
