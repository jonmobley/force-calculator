import XCTest
import ForceShared

/// Covers the force number and activation count arriving from outside the settings screen:
/// an old tag's query string, or a config fetched from the service.
///
/// Neither went through the picker or the number editor, so either could carry a value the
/// app never offers. An activation count of zero forced on every equals press.
final class SettingsLimitsTests: XCTestCase {
    // MARK: - Links

    func testLinkActivationCountIsBroughtIntoRange() {
        XCTAssertEqual(applied("ac=0").activationCount, 1)
        XCTAssertEqual(applied("ac=-4").activationCount, 1)
        XCTAssertEqual(applied("ac=99").activationCount, 10)
        XCTAssertEqual(applied("ac=7").activationCount, 7)
    }

    func testLinkForceNumberIsBroughtIntoRange() {
        XCTAssertEqual(applied("fn=-12").forceNumber, 0)
        XCTAssertEqual(applied("fn=123456789012").forceNumber, 9_999_999_999)
        XCTAssertEqual(applied("fn=4556325").forceNumber, 4_556_325)
    }

    // MARK: - Fetched config

    func testDecodedSettingsAreBroughtIntoRange() throws {
        let json = """
        {"theme":"dark","forceNumber":-5,"activationCount":0,
         "currentCount":0,"magicTrickMode":"Force Number"}
        """
        let settings = try JSONDecoder().decode(CalculatorSettings.self, from: Data(json.utf8))
        XCTAssertEqual(settings.forceNumber, 0)
        XCTAssertEqual(settings.activationCount, 1)
    }

    // MARK: - Helpers

    private func applied(_ query: String) -> CalculatorSettings {
        let settings = CalculatorSettings()
        let url = URL(string: "https://appclip.apple.com/id?p=x&\(query)")!
        AppClipQuery.apply(url, to: settings)
        return settings
    }
}
