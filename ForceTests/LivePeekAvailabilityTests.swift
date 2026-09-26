import XCTest
import ForceShared

/// Live Peek is held back from the first release. A performer who turned it on in a
/// TestFlight build, a config published by that build, or an old tag carrying `pk=true`
/// must still leave the clip sending nothing.
final class LivePeekAvailabilityTests: XCTestCase {
    override func setUpWithError() throws {
        try XCTSkipIf(CalculatorSettings.livePeekAvailable, "Live Peek is available")
    }

    // MARK: - Tests

    func testStoredOrFetchedRecordCannotTurnPeekOn() throws {
        let json = """
        {"theme":"dark","forceNumber":42,"activationCount":1,
         "currentCount":0,"magicTrickMode":"Force Number","livePeekEnabled":true}
        """
        let decoded = try JSONDecoder().decode(CalculatorSettings.self, from: Data(json.utf8))
        XCTAssertFalse(decoded.livePeekEnabled)
        XCTAssertEqual(decoded.forceNumber, 42)
    }

    func testApplyingAStoredRecordCannotTurnPeekOn() {
        let stored = CalculatorSettings()
        stored.livePeekEnabled = true
        let settings = CalculatorSettings()
        settings.applyStored(stored)
        XCTAssertFalse(settings.livePeekEnabled)
    }

    func testLinkFlagCannotTurnPeekOn() {
        let settings = CalculatorSettings()
        let url = URL(string: "https://appclip.apple.com/id?p=x&pk=true")!
        AppClipQuery.apply(url, to: settings)
        XCTAssertFalse(settings.livePeekEnabled)
    }
}
