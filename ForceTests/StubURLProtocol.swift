import Foundation

/// Answers requests from a closure instead of the network, so service code that takes a
/// `URLSession` can be tested without the Worker.
///
/// Each stub gets its own session, tagged with a header, so tests that run in parallel
/// never see each other's handlers or requests.
final class StubURLProtocol: URLProtocol {
    /// What the handler returns: a status code and a body.
    typealias Handler = (URLRequest) throws -> (status: Int, body: Data)

    private static let tagHeader = "X-Stub-Tag"
    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]

    // MARK: - Setup

    /// A session whose every request is answered by `handler`.
    static func session(handler: @escaping Handler) -> URLSession {
        let tag = UUID().uuidString
        lock.withLock { handlers[tag] = handler }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        configuration.httpAdditionalHeaders = [tagHeader: tag]
        return URLSession(configuration: configuration)
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let tag = request.value(forHTTPHeaderField: Self.tagHeader) ?? ""
        guard let handler = Self.lock.withLock({ Self.handlers[tag] }),
              let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (status, body) = try handler(Self.withBody(request))
            let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // MARK: - Helpers

    /// URLSession hands a protocol the body as a stream; put it back so handlers can read it.
    private static func withBody(_ request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let stream = request.httpBodyStream else { return request }
        var copy = request
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        stream.open()
        defer { stream.close() }
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: buffer.count)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        copy.httpBody = data
        return copy
    }
}
