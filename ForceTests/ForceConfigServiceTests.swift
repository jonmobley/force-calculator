import XCTest
import ForceShared

/// Covers the requests `ForceConfigService` sends and how it reads the Worker's answers.
/// The session is stubbed, so these run without the network.
final class ForceConfigServiceTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
    }

    // MARK: - Fetch

    func testFetchAsksForThePerformersRecordWithoutCredentials() async throws {
        let recorder = Recorder()
        let published = CalculatorSettings()
        published.forceNumber = 4_556_325
        published.activationCount = 3
        let body = try JSONEncoder().encode(published)
        let session = StubURLProtocol.session { request in
            recorder.requests.append(request)
            return (200, body)
        }

        let fetched = try await ForceConfigService.fetch(id: "abc123", session: session)

        XCTAssertEqual(fetched.forceNumber, 4_556_325)
        XCTAssertEqual(fetched.activationCount, 3)
        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/v1/config")
        XCTAssertEqual(query(request)["id"], "abc123")
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testFetchBringsOutOfRangeValuesIntoRange() async throws {
        let json = """
        {"theme":"dark","forceNumber":-5,"activationCount":0,
         "currentCount":0,"magicTrickMode":"Force Number"}
        """
        let session = StubURLProtocol.session { _ in (200, Data(json.utf8)) }

        let fetched = try await ForceConfigService.fetch(id: "p", session: session)

        XCTAssertEqual(fetched.forceNumber, 0)
        XCTAssertEqual(fetched.activationCount, 1)
    }

    func testFetchReportsAnUnpublishedOrErasedRecordAsNotPublished() async {
        await assertFetch(throws: .notPublished, session: stub(status: 404))
    }

    func testFetchMapsServerFailures() async {
        await assertFetch(throws: .unauthorized, session: stub(status: 401))
        await assertFetch(throws: .server(status: 429), session: stub(status: 429))
        await assertFetch(throws: .server(status: 500), session: stub(status: 500))
    }

    func testFetchRejectsABodyThatIsNotSettings() async {
        let session = StubURLProtocol.session { _ in (200, Data("{}".utf8)) }
        await assertFetch(throws: .malformedResponse, session: session)
    }

    // MARK: - Publish

    func testPublishSendsTheSettingsWithTheBearerToken() async throws {
        let recorder = Recorder()
        let session = StubURLProtocol.session { request in
            recorder.requests.append(request)
            return (204, Data())
        }
        let settings = CalculatorSettings()
        settings.forceNumber = 1234

        try await ForceConfigService.publish(
            settings, id: "abc123", token: "secret", session: session
        )

        let request = try XCTUnwrap(recorder.requests.first)
        XCTAssertEqual(request.httpMethod, "PUT")
        XCTAssertEqual(query(request)["id"], "abc123")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let sent = try JSONDecoder().decode(
            CalculatorSettings.self, from: try XCTUnwrap(request.httpBody)
        )
        XCTAssertEqual(sent.forceNumber, 1234)
    }

    func testPublishReportsAClaimedIdAsUnauthorized() async {
        let session = stub(status: 401)
        do {
            try await ForceConfigService.publish(
                CalculatorSettings(), id: "p", token: "wrong", session: session
            )
            XCTFail("Expected unauthorized")
        } catch {
            XCTAssertEqual(error as? ForceConfigService.ServiceError, .unauthorized)
        }
    }

    func testPublishReportsTheWriteLimit() async {
        let session = stub(status: 429)
        do {
            try await ForceConfigService.publish(
                CalculatorSettings(), id: "p", token: "t", session: session
            )
            XCTFail("Expected a server error")
        } catch {
            XCTAssertEqual(error as? ForceConfigService.ServiceError, .server(status: 429))
        }
    }

    // MARK: - Helpers

    /// A session that answers every request with `status` and a Worker-style error body.
    private func stub(status: Int) -> URLSession {
        StubURLProtocol.session { _ in (status, Data(#"{"error":"stub"}"#.utf8)) }
    }

    private func query(_ request: URLRequest) -> [String: String] {
        let items = request.url.flatMap {
            URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems
        } ?? []
        let pairs = items.map { ($0.name, $0.value ?? "") }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    private func assertFetch(
        throws expected: ForceConfigService.ServiceError,
        session: URLSession,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await ForceConfigService.fetch(id: "p", session: session)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(
                error as? ForceConfigService.ServiceError, expected, file: file, line: line
            )
        }
    }
}
