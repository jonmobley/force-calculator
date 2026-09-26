import XCTest
import ForceShared

/// Covers the round trip between what the readout shows and the number the next key works on.
///
/// Every operator press reads the display back through `parseDisplay`, so anything
/// `formatResult` writes has to parse to the same value on any device.
final class CalculatorFormatterTests: XCTestCase {
    // MARK: - Round trip

    /// A comma-decimal locale used to turn `12.5` into `12,5`, which parsed back as `125`.
    func testResultsParseBackToTheSameValue() {
        for value in [12.5, -0.25, 1_234.5678, 4_556_225, 9_999_999_999] {
            let shown = CalculatorFormatter.formatResult(value)
            XCTAssertEqual(CalculatorFormatter.parseDisplay(shown), value, "via \(shown)")
        }
    }

    func testResultsUseAPointAndCommaGrouping() {
        XCTAssertEqual(CalculatorFormatter.formatResult(1_234_567.5), "1,234,567.5")
        XCTAssertEqual(CalculatorFormatter.formatResult(12.5), "12.5")
    }

    func testOversizedResultsFallBackToScientific() {
        XCTAssertEqual(CalculatorFormatter.formatResult(12_345_678_901), "1.235e10")
    }

    // MARK: - Typing

    func testTypedDigitsAreGrouped() {
        XCTAssertEqual(CalculatorFormatter.formatDisplay("1234567"), "1,234,567")
        XCTAssertEqual(CalculatorFormatter.formatDisplay("-1234.50"), "-1,234.50")
        XCTAssertEqual(CalculatorFormatter.formatDisplay("0"), "0")
    }

    func testParsingIgnoresGrouping() {
        XCTAssertEqual(CalculatorFormatter.parseDisplay("1,234,567.25"), 1_234_567.25)
        XCTAssertEqual(CalculatorFormatter.parseDisplay("Error"), 0)
    }
}
