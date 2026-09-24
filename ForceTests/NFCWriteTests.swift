import CoreNFC
import XCTest
@testable import ForceShared

/// Device-side checks for the NFC sticker path.
///
/// Writing a tag still needs a physical sticker under the phone. These tests confirm the
/// phone can open that path and that the URL we would write names a performer.
final class NFCWriteTests: XCTestCase {
    func testNFCHardwareIsAvailableOnThisDevice() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Simulator has no NFC radio")
        #else
        XCTAssertTrue(
            NFCNDEFReaderSession.readingAvailable,
            "BeastMode must be able to write stickers"
        )
        #endif
    }

    func testStableInvocationCarriesThePerformerId() {
        let id = "nfcCheckId_abc123"
        let url = AppClipQuery.stableURL(performer: id)
        XCTAssertEqual(AppClipQuery.performerID(in: url), id)
        XCTAssertTrue(url.absoluteString.contains("id=\(id)"))
        XCTAssertTrue(
            url.absoluteString.hasPrefix("https://appclip.apple.com/id"),
            "stickers must use Apple's invocation host"
        )
    }
}
