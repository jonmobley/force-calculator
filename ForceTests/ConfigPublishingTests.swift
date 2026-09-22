import XCTest
import ForceShared
@testable import Force

/// Covers the pieces of config publishing that do not need the network.
@MainActor
final class ConfigPublishingTests: XCTestCase {
    override func tearDown() {
        ConfigTokenStore.delete()
        super.tearDown()
    }

    func testTokenRoundTripsThroughKeychain() {
        ConfigTokenStore.delete()
        XCTAssertNil(ConfigTokenStore.load())

        XCTAssertTrue(ConfigTokenStore.save("test-token-value"))
        XCTAssertEqual(ConfigTokenStore.load(), "test-token-value")

        // Replacing rather than duplicating matters: a stale duplicate would make
        // publishing fail with a rejected token.
        XCTAssertTrue(ConfigTokenStore.save("replacement"))
        XCTAssertEqual(ConfigTokenStore.load(), "replacement")

        XCTAssertTrue(ConfigTokenStore.delete())
        XCTAssertNil(ConfigTokenStore.load())
    }

    func testBlankTokenIsTreatedAsNoToken() {
        ConfigTokenStore.save("something")
        ConfigTokenStore.save("   ")
        XCTAssertNil(ConfigTokenStore.load(), "Whitespace must not be stored as a token")
    }

    /// Without a token nothing is published, and the UI must say so rather than
    /// implying the service is up to date.
    func testPublisherReportsMissingTokenAndDoesNotClaimSynced() {
        ConfigTokenStore.delete()
        let publisher = ForceConfigPublisher()
        let settings = CalculatorSettings()

        publisher.start(observing: settings)

        XCTAssertEqual(publisher.state, .missingToken)
    }

    func testPublisherStartsPublishingOnceATokenExists() {
        ConfigTokenStore.save("token-for-test")
        let publisher = ForceConfigPublisher()
        let settings = CalculatorSettings()

        publisher.start(observing: settings)

        // The upload is asynchronous; what matters here is that it was attempted
        // at launch rather than waiting for the first edit.
        XCTAssertEqual(publisher.state, .publishing)
    }
}
