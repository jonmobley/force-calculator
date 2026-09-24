import XCTest
import ForceShared
@testable import Force

/// Covers the pieces of config publishing that do not need the network.
@MainActor
final class ConfigPublishingTests: XCTestCase {
    /// Private keychain service for this test. Parallel classes share a simulator,
    /// so they must not touch the performer's real service.
    private let service = "com.mobleypro.mobley.Force.tests.\(UUID().uuidString)"

    override func tearDown() {
        ConfigTokenStore.delete(service: service)
        ConfigTokenStore.delete(account: ConfigTokenStore.performerAccount, service: service)
        PerformerCredentials.forgetCache(service: service)
        super.tearDown()
    }

    func testTokenRoundTripsThroughKeychain() {
        ConfigTokenStore.delete(service: service)
        XCTAssertNil(ConfigTokenStore.load(service: service))

        XCTAssertTrue(ConfigTokenStore.save("test-token-value", service: service))
        XCTAssertEqual(ConfigTokenStore.load(service: service), "test-token-value")

        // Replacing rather than duplicating matters: a stale duplicate would make
        // publishing fail with a rejected token.
        XCTAssertTrue(ConfigTokenStore.save("replacement", service: service))
        XCTAssertEqual(ConfigTokenStore.load(service: service), "replacement")

        XCTAssertTrue(ConfigTokenStore.delete(service: service))
        XCTAssertNil(ConfigTokenStore.load(service: service))
    }

    func testBlankTokenIsTreatedAsNoToken() {
        ConfigTokenStore.save("something", service: service)
        ConfigTokenStore.save("   ", service: service)
        XCTAssertNil(ConfigTokenStore.load(service: service), "Whitespace must not be stored as a token")
    }

    /// Publishing needs no setup from the performer, so the very first launch has to
    /// reach the service on its own rather than waiting for a token to be pasted in.
    func testPublisherStartsPublishingWithNoSetup() {
        let publisher = ForceConfigPublisher { _, _, _ in }
        publisher.start(observing: CalculatorSettings())

        // The upload is asynchronous; what matters here is that it was attempted
        // at launch rather than waiting for the first edit.
        XCTAssertEqual(publisher.state, .publishing)
    }

    /// Credentials are generated once and then reused, so the id printed on a QR code
    /// stays the same across launches. A changing id would strand every tag in the wild.
    func testCredentialsAreGeneratedOnceAndKept() {
        ConfigTokenStore.delete(service: service)
        ConfigTokenStore.delete(account: ConfigTokenStore.performerAccount, service: service)
        PerformerCredentials.forgetCache(service: service)

        let first = PerformerCredentials.current(service: service)
        XCTAssertTrue(PerformerID.isValid(first.identifier))
        XCTAssertFalse(first.writeToken.isEmpty)
        XCTAssertNotEqual(first.identifier, first.writeToken)

        PerformerCredentials.forgetCache(service: service)
        let second = PerformerCredentials.current(service: service)
        XCTAssertEqual(first.identifier, second.identifier)
        XCTAssertEqual(first.writeToken, second.writeToken)
    }

    /// A fresh install must not land on the shared id: that was the record everybody
    /// used to write to, and joining it would put this performer back in the crowd.
    func testAFreshInstallDoesNotTakeTheSharedID() {
        ConfigTokenStore.delete(service: service)
        ConfigTokenStore.delete(account: ConfigTokenStore.performerAccount, service: service)
        PerformerCredentials.forgetCache(service: service)

        let identifier = PerformerCredentials.current(service: service).identifier
        XCTAssertNotEqual(identifier, PerformerID.shared)
    }

    /// An install that was already publishing keeps the shared id, because its QR codes
    /// and NFC stickers all point at it.
    func testAnInstallThatAlreadyPublishedKeepsItsRecord() {
        ConfigTokenStore.delete(account: ConfigTokenStore.performerAccount, service: service)
        ConfigTokenStore.save("token-from-before-the-upgrade", service: service)
        PerformerCredentials.forgetCache(service: service)

        let credentials = PerformerCredentials.current(service: service)
        XCTAssertEqual(credentials.identifier, PerformerID.shared)
        XCTAssertEqual(credentials.writeToken, "token-from-before-the-upgrade")
    }

    /// Two installs must never collide, or they are back to sharing one record.
    func testGeneratedIDsAreDistinct() {
        let ids = (0..<200).map { _ in PerformerID.generate() }
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertTrue(ids.allSatisfy(PerformerID.isValid))
    }
}
